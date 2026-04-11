import AppKit
import Carbon.HIToolbox
import Observation

extension Notification.Name {
    static let fnKeyEvent = Notification.Name("com.verbo.fnKeyEvent")
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
    }

    func unregister(id: String) {
        bindings = bindings.filter { $0.id != id }
    }

    // MARK: - Monitoring

    func startListening() {
        stopListening()

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
        // Check accessibility permission first
        let trusted = AXIsProcessTrusted()
        debugLog("[CGEventTap] AXIsProcessTrusted = \(trusted)")

        let callback: CGEventTapCallBack = { _, _, event, _ in
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // Post modifier key events for Fn and modifier-only hotkeys
            NotificationCenter.default.post(
                name: .fnKeyEvent,
                object: nil,
                userInfo: ["keyCode": Int(keyCode), "flags": flags.rawValue]
            )

            return Unmanaged.passRetained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.flagsChanged.rawValue),
            callback: callback,
            userInfo: nil
        ) else {
            debugLog("[CGEventTap] FAILED to create tap! Input Monitoring permission missing?")
            return
        }

        debugLog("[CGEventTap] Tap created successfully")
        cgEventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        cgRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // Listen for modifier key notifications from CGEvent tap
        NotificationCenter.default.addObserver(
            forName: .fnKeyEvent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let keyCode = notification.userInfo?["keyCode"] as? Int,
                  let flagsRaw = notification.userInfo?["flags"] as? UInt64 else { return }
            Task { @MainActor in
                self?.handleModifierEvent(keyCode: UInt16(keyCode), flagsRaw: flagsRaw)
            }
        }
    }

    private nonisolated func debugLog(_ msg: String) {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".verbo")
        let path = dir.appendingPathComponent("debug.log")
        let line = "\(msg)\n"
        if let data = line.data(using: .utf8), let fh = try? FileHandle(forWritingTo: path) {
            fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
        }
    }

    private func stopCGEventTap() {
        if let tap = cgEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            cgEventTap = nil
        }
        if let source = cgRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            cgRunLoopSource = nil
        }
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
