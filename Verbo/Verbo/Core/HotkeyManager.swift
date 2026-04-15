import AppKit
import Carbon.HIToolbox
import IOKit.hid
import Observation

extension Notification.Name {
    static let fnKeyEvent = Notification.Name("com.verbo.fnKeyEvent")
}

/// Box to carry @MainActor closures across Sendable boundaries.
/// The closures are only invoked via DispatchQueue.main + MainActor.assumeIsolated.
final class UnsafeSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

/// Thread-safe state shared between CGEventTap callback and HotkeyManager.
/// The callback runs on a dedicated thread and mutates state directly (no async chain).
/// When a hotkey fires, onTrigger is called (also from dedicated thread) — it must
/// dispatch to main actor itself.
final class HotkeyTapState: @unchecked Sendable {
    /// Shared instance used for recording-mode coordination with KeyRecorderView.
    /// The real instance is assigned by HotkeyManager.startListening().
    nonisolated(unsafe) static weak var shared: HotkeyTapState?

    private let lock = NSLock()

    /// When non-nil, the tap callback forwards ALL modifier events here instead
    /// of firing registered bindings. Used by KeyRecorderView to record shortcuts.
    /// The closure receives (keyCode, flagsRaw).
    nonisolated(unsafe) var recordingHandler: ((UInt16, UInt64) -> Void)?

    // Hotkey bindings that should be matched in the callback.
    struct FnBinding {
        let onPress: @Sendable () -> Void
        let onRelease: (@Sendable () -> Void)?
    }

    struct ModifierOnlyBinding {
        let keyCode: UInt16
        let flag: UInt64
        let onPress: @Sendable () -> Void
        let onRelease: (@Sendable () -> Void)?
    }

    // Tap reference so the callback can re-enable it after timeout.
    var tap: CFMachPort?

    private var fnBinding: FnBinding?
    private var modifierOnlyBindings: [ModifierOnlyBinding] = []
    private var fnPressed = false
    private var modifierPressed: [UInt16: Bool] = [:]

    func setFnBinding(_ binding: FnBinding?) {
        lock.lock(); defer { lock.unlock() }
        fnBinding = binding
    }

    func setModifierOnlyBindings(_ bindings: [ModifierOnlyBinding]) {
        lock.lock(); defer { lock.unlock() }
        modifierOnlyBindings = bindings
    }

    /// Called from the tap callback (dedicated thread) on flagsChanged events.
    /// Returns true if this event matched a registered hotkey (should be blocked).
    func handleFlagsChanged(keyCode: UInt16, flagsRaw: UInt64) -> Bool {
        // If recording mode is active, forward the event and consume it.
        // This bypasses all registered bindings so KeyRecorderView can capture
        // keys that would otherwise be consumed by our existing bindings.
        if let handler = recordingHandler {
            handler(keyCode, flagsRaw)
            return true  // consume so system doesn't handle either
        }

        lock.lock()
        defer { lock.unlock() }

        // Fn key (keyCode 0x3F) — tracked via MaskSecondaryFn flag
        if keyCode == 0x3F {
            let isDown = (flagsRaw & CGEventFlags.maskSecondaryFn.rawValue) != 0
            guard let binding = fnBinding else { return false }
            if isDown != fnPressed {
                fnPressed = isDown
                // Invoke outside lock is fine here since DispatchQueue.main.async
                // in the closures doesn't re-enter the lock.
                if isDown {
                    binding.onPress()
                } else {
                    binding.onRelease?()
                }
            }
            return true  // Consume the Fn event — prevent system from handling it
        }

        // Modifier-only keys (right cmd, etc.) — do NOT block (user may still use them normally)
        for binding in modifierOnlyBindings where binding.keyCode == keyCode {
            let isDown = (flagsRaw & binding.flag) != 0
            let wasDown = modifierPressed[keyCode] ?? false
            if isDown != wasDown {
                modifierPressed[keyCode] = isDown
                if isDown {
                    binding.onPress()
                } else {
                    binding.onRelease?()
                }
            }
        }

        return false
    }
}

// MARK: - HotkeyManager

@Observable
@MainActor
final class HotkeyManager {

    // MARK: - HotkeyBinding

    enum HotkeyType {
        case normal(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)
        case fnKey
        case modifierOnly(keyCode: UInt16)  // e.g. right Command alone
    }

    struct HotkeyBinding {
        let id: String
        let type: HotkeyType
        let onPress: @MainActor () -> Void
        let onRelease: (@MainActor () -> Void)?
    }

    // MARK: - Properties

    private var globalMonitor: Any?
    private var localMonitor: Any?
    nonisolated(unsafe) private var cgEventTap: CFMachPort?
    nonisolated(unsafe) private var cgRunLoopSource: CFRunLoopSource?
    nonisolated(unsafe) private var tapThread: Thread?
    nonisolated(unsafe) private var tapRunLoop: CFRunLoop?
    private let tapState = HotkeyTapState()
    private var bindings: [HotkeyBinding] = []
    private var fnPressed = false

    // MARK: - Registration

    // Right Command keyCode = 54, Left Command = 55
    private static let modifierOnlyKeys: [String: UInt16] = [
        "rightcommand": 54, "rightcmd": 54,
        "leftcommand": 55, "leftcmd": 55,
        "rightoption": 61, "rightalt": 61,
        "leftoption": 58, "leftalt": 58,
        "rightshift": 60, "leftshift": 56,
        "rightcontrol": 62, "rightctrl": 62,
        "leftcontrol": 59, "leftctrl": 59,
    ]

    func register(
        id: String,
        shortcut: String,
        onPress: @escaping @MainActor () -> Void,
        onRelease: (@MainActor () -> Void)? = nil
    ) {
        let lower = shortcut.lowercased().replacingOccurrences(of: " ", with: "")
        let hotkeyType: HotkeyType

        if lower == "fn" {
            hotkeyType = .fnKey
        } else if let keyCode = Self.modifierOnlyKeys[lower] {
            hotkeyType = .modifierOnly(keyCode: keyCode)
        } else {
            guard let parsed = HotkeyManager.parseShortcut(shortcut) else { return }
            hotkeyType = .normal(keyCode: parsed.keyCode, modifiers: parsed.modifiers)
        }

        let binding = HotkeyBinding(id: id, type: hotkeyType, onPress: onPress, onRelease: onRelease)
        bindings = bindings.filter { $0.id != id } + [binding]
        syncBindingsToTapState()
    }

    /// Re-sync the Fn and modifier-only bindings into the tap state so the
    /// dedicated-thread callback can call them synchronously.
    private func syncBindingsToTapState() {
        // Fn binding
        var fnBinding: HotkeyTapState.FnBinding?
        for binding in bindings {
            if case .fnKey = binding.type {
                let onPressBox = UnsafeSendableBox(binding.onPress)
                let onReleaseBox = binding.onRelease.map { UnsafeSendableBox($0) }
                let pressClosure: @Sendable () -> Void = {
                    DebugLog.write("[hotkey] onPress dispatch to main")
                    DispatchQueue.main.async {
                        DebugLog.write("[hotkey] onPress on main, invoking callback")
                        MainActor.assumeIsolated { onPressBox.value() }
                    }
                }
                var releaseClosure: (@Sendable () -> Void)? = nil
                if let box = onReleaseBox {
                    releaseClosure = {
                        DispatchQueue.main.async {
                            MainActor.assumeIsolated { box.value() }
                        }
                    }
                }
                fnBinding = HotkeyTapState.FnBinding(onPress: pressClosure, onRelease: releaseClosure)
                break
            }
        }
        tapState.setFnBinding(fnBinding)

        // Modifier-only bindings
        var modBindings: [HotkeyTapState.ModifierOnlyBinding] = []
        for binding in bindings {
            guard case .modifierOnly(let keyCode) = binding.type else { continue }
            let flag: UInt64
            switch keyCode {
            case 54, 55: flag = 0x100010 // Command
            case 58, 61: flag = 0x80020  // Option
            case 56, 60: flag = 0x20002  // Shift
            case 59, 62: flag = 0x40001  // Control
            default: continue
            }
            let onPressBox = UnsafeSendableBox(binding.onPress)
            let onReleaseBox = binding.onRelease.map { UnsafeSendableBox($0) }
            let pressClosure: @Sendable () -> Void = {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { onPressBox.value() }
                }
            }
            var releaseClosure: (@Sendable () -> Void)? = nil
            if let box = onReleaseBox {
                releaseClosure = {
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { box.value() }
                    }
                }
            }
            modBindings.append(HotkeyTapState.ModifierOnlyBinding(
                keyCode: keyCode,
                flag: flag,
                onPress: pressClosure,
                onRelease: releaseClosure
            ))
        }
        tapState.setModifierOnlyBindings(modBindings)
    }

    func unregister(id: String) {
        bindings = bindings.filter { $0.id != id }
        syncBindingsToTapState()
    }

    // MARK: - Monitoring

    func startListening() {
        stopListening()

        // Expose tap state for KeyRecorderView coordination
        HotkeyTapState.shared = tapState

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleEvent(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleEvent(event)
            }
            return event
        }

        // CGEvent tap to capture Fn/Globe key (NSEvent monitors can't see it)
        startCGEventTap()
    }

    func stopListening() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        stopCGEventTap()
    }

    // MARK: - CGEvent Tap for Fn Key

    nonisolated private func startCGEventTap() {
        let trusted = AXIsProcessTrusted()
        debugLog("[CGEventTap] AXIsProcessTrusted = \(trusted)")

        let state = self.tapState
        let stateRefcon = Unmanaged.passUnretained(state).toOpaque()

        // Run CGEventTap on a dedicated thread — avoids timeouts when main thread is busy
        let thread = Thread {
            let callback: CGEventTapCallBack = { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let state = Unmanaged<HotkeyTapState>.fromOpaque(refcon).takeUnretainedValue()

                // Re-enable tap if macOS disabled it due to timeout
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = state.tap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                guard type == .flagsChanged else {
                    return Unmanaged.passUnretained(event)
                }

                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let flagsRaw = event.flags.rawValue

                // Synchronous handling on this dedicated thread — no async chain
                let consumed = state.handleFlagsChanged(keyCode: keyCode, flagsRaw: flagsRaw)

                // Return nil to block the event (prevent system from handling Fn)
                if consumed {
                    return nil
                }
                return Unmanaged.passUnretained(event)
            }

            let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)

            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: callback,
                userInfo: stateRefcon
            ) else {
                self.debugLog("[CGEventTap] FAILED to create tap on dedicated thread")
                return
            }

            self.cgEventTap = tap
            state.tap = tap  // Allow callback to re-enable on timeout
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            self.cgRunLoopSource = source
            let runLoop = CFRunLoopGetCurrent()
            self.tapRunLoop = runLoop
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)

            self.debugLog("[CGEventTap] Tap running on dedicated thread")
            CFRunLoopRun()  // blocks this thread forever, processing events
            self.debugLog("[CGEventTap] Dedicated thread run loop exited")
        }
        thread.name = "com.verbo.HotkeyTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        self.tapThread = thread
    }

    // MARK: - IOHIDManager for Fn Key (lowest level)

    nonisolated private func startIOHIDMonitor() {
        guard let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone)) as IOHIDManager? else {
            debugLog("[IOHID] Failed to create manager")
            return
        }

        let matchDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
        ]
        IOHIDManagerSetDeviceMatching(manager, matchDict as CFDictionary)

        let callback: IOHIDValueCallback = { _, _, _, value in
            let element = IOHIDValueGetElement(value)
            let usagePage = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            let intValue = IOHIDValueGetIntegerValue(value)

            // HID Keyboard page: usage 0x07 = keyboard, modifiers are 0xE0-0xE7
            // Fn key on Apple keyboards: some report as usage 0x03 on page 0xFF (Apple vendor)
            // or as usage on consumer page 0x0C

            // Log modifier and special keys
            let isModifier = (usagePage == 0x07 && usage >= 0xE0)
            let isAppleVendor = (usagePage == 0xFF)
            let isConsumer = (usagePage == 0x0C)

            if isModifier || isAppleVendor || isConsumer {
                let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".verbo")
                let path = dir.appendingPathComponent("debug.log")
                let line = "[IOHID] page=\(String(usagePage, radix:16)) usage=\(String(usage, radix:16)) value=\(intValue)\n"
                if let data = line.data(using: .utf8), let fh = try? FileHandle(forWritingTo: path) {
                    fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
                }
            }
        }

        IOHIDManagerRegisterInputValueCallback(manager, callback, nil)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        debugLog("[IOHID] Manager opened, result=\(result)")
    }

    private nonisolated func debugLog(_ msg: String) {
        DebugLog.write(msg)
    }

    private func stopCGEventTap() {
        if let tap = cgEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            cgEventTap = nil
        }
        if let runLoop = tapRunLoop {
            CFRunLoopStop(runLoop)
            tapRunLoop = nil
        }
        cgRunLoopSource = nil
        tapThread = nil
    }

    /// Track which modifier keys are currently pressed (by keyCode)
    private var pressedModifiers: Set<UInt16> = []

    private func handleModifierEvent(keyCode: UInt16, flagsRaw: UInt64) {
        // Determine if this modifier key is being pressed or released.
        // For modifier keys, we detect press/release by checking if the
        // corresponding flag is set in the event flags.
        let modifierFlagForKeyCode: UInt64? = switch keyCode {
        case 54, 55: 0x100010 // Command (either side)
        case 58, 61: 0x80020  // Option (either side)
        case 56, 60: 0x20002  // Shift (either side)
        case 59, 62: 0x40001  // Control (either side)
        case 63:     0x800000 // Fn
        default: nil
        }

        guard let flag = modifierFlagForKeyCode else { return }
        let isDown = (flagsRaw & flag) != 0

        for binding in bindings {
            switch binding.type {
            case .fnKey where keyCode == 63:
                if isDown && !pressedModifiers.contains(keyCode) {
                    binding.onPress()
                } else if !isDown && pressedModifiers.contains(keyCode) {
                    binding.onRelease?()
                }
            case .modifierOnly(let bKeyCode) where bKeyCode == keyCode:
                if isDown && !pressedModifiers.contains(keyCode) {
                    binding.onPress()
                } else if !isDown && pressedModifiers.contains(keyCode) {
                    binding.onRelease?()
                }
            default:
                break
            }
        }

        if isDown {
            pressedModifiers.insert(keyCode)
        } else {
            pressedModifiers.remove(keyCode)
        }
    }

    // MARK: - Fn Key Handling

    // MARK: - Event Handling

    private func handleEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])

        for binding in bindings {
            guard case .normal(let bKeyCode, let bModifiers) = binding.type,
                  bKeyCode == keyCode, bModifiers == modifiers else { continue }

            if event.type == .keyDown, !event.isARepeat {
                binding.onPress()
            } else if event.type == .keyUp {
                binding.onRelease?()
            }
        }
    }

    // MARK: - Display Formatting

    static func displayString(for shortcut: String) -> String {
        let parts = shortcut.split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }
        return parts.map { part in
            switch part.lowercased().replacingOccurrences(of: " ", with: "") {
            case "rightcommand", "rightcmd": return "R⌘"
            case "leftcommand", "leftcmd": return "L⌘"
            case "command", "cmd", "commandorcontrol": return "⌘"
            case "rightoption", "rightalt": return "R⌥"
            case "leftoption", "leftalt": return "L⌥"
            case "option", "alt": return "⌥"
            case "rightshift": return "R⇧"
            case "leftshift": return "L⇧"
            case "shift": return "⇧"
            case "rightcontrol", "rightctrl": return "R⌃"
            case "leftcontrol", "leftctrl": return "L⌃"
            case "control", "ctrl": return "⌃"
            case "fn": return "fn"
            case "space": return "␣"
            case "return", "enter": return "↩"
            case "escape", "esc": return "⎋"
            case "tab": return "⇥"
            case "delete", "backspace": return "⌫"
            default: return part.uppercased()
            }
        }.joined()
    }

    // MARK: - Shortcut Parsing

    static func parseShortcut(_ shortcut: String) -> (keyCode: UInt16, modifiers: NSEvent.ModifierFlags)? {
        let parts = shortcut.split(separator: "+").map { $0.lowercased() }
        guard !parts.isEmpty else { return nil }

        var modifiers: NSEvent.ModifierFlags = []
        var keyPart: String? = nil

        for part in parts {
            switch part {
            case "cmd", "command", "commandorcontrol":
                modifiers.insert(.command)
            case "ctrl", "control":
                modifiers.insert(.control)
            case "alt", "option":
                modifiers.insert(.option)
            case "shift":
                modifiers.insert(.shift)
            default:
                keyPart = part
            }
        }

        guard let key = keyPart, let keyCode = keyCodeForKey(key) else { return nil }
        return (keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: - Key Code Mapping

    // swiftlint:disable:next cyclomatic_complexity
    private static func keyCodeForKey(_ key: String) -> UInt16? {
        switch key {
        // Letters a-z
        case "a": return UInt16(kVK_ANSI_A)
        case "b": return UInt16(kVK_ANSI_B)
        case "c": return UInt16(kVK_ANSI_C)
        case "d": return UInt16(kVK_ANSI_D)
        case "e": return UInt16(kVK_ANSI_E)
        case "f": return UInt16(kVK_ANSI_F)
        case "g": return UInt16(kVK_ANSI_G)
        case "h": return UInt16(kVK_ANSI_H)
        case "i": return UInt16(kVK_ANSI_I)
        case "j": return UInt16(kVK_ANSI_J)
        case "k": return UInt16(kVK_ANSI_K)
        case "l": return UInt16(kVK_ANSI_L)
        case "m": return UInt16(kVK_ANSI_M)
        case "n": return UInt16(kVK_ANSI_N)
        case "o": return UInt16(kVK_ANSI_O)
        case "p": return UInt16(kVK_ANSI_P)
        case "q": return UInt16(kVK_ANSI_Q)
        case "r": return UInt16(kVK_ANSI_R)
        case "s": return UInt16(kVK_ANSI_S)
        case "t": return UInt16(kVK_ANSI_T)
        case "u": return UInt16(kVK_ANSI_U)
        case "v": return UInt16(kVK_ANSI_V)
        case "w": return UInt16(kVK_ANSI_W)
        case "x": return UInt16(kVK_ANSI_X)
        case "y": return UInt16(kVK_ANSI_Y)
        case "z": return UInt16(kVK_ANSI_Z)
        // Special keys
        case "space": return UInt16(kVK_Space)
        case "return", "enter": return UInt16(kVK_Return)
        case "escape", "esc": return UInt16(kVK_Escape)
        case "tab": return UInt16(kVK_Tab)
        case "delete", "backspace": return UInt16(kVK_Delete)
        default: return nil
        }
    }
}
