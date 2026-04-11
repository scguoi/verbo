import AppKit
import Carbon.HIToolbox
import Observation

// MARK: - HotkeyManager

@Observable
@MainActor
final class HotkeyManager {

    // MARK: - HotkeyBinding

    struct HotkeyBinding {
        let id: String
        let keyCode: UInt16
        let modifiers: NSEvent.ModifierFlags
        let onPress: @MainActor () -> Void
        let onRelease: (@MainActor () -> Void)?
    }

    // MARK: - Properties

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var bindings: [HotkeyBinding] = []

    // MARK: - Registration

    func register(
        id: String,
        shortcut: String,
        onPress: @escaping @MainActor () -> Void,
        onRelease: (@MainActor () -> Void)? = nil
    ) {
        guard let parsed = HotkeyManager.parseShortcut(shortcut) else { return }
        let binding = HotkeyBinding(
            id: id,
            keyCode: parsed.keyCode,
            modifiers: parsed.modifiers,
            onPress: onPress,
            onRelease: onRelease
        )
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
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])

        for binding in bindings {
            guard binding.keyCode == keyCode,
                  binding.modifiers == modifiers else { continue }

            if event.type == .keyDown, !event.isARepeat {
                binding.onPress()
            } else if event.type == .keyUp {
                binding.onRelease?()
            }
        }
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
