import AppKit
import SwiftUI

/// A hotkey recorder button. Click to enter recording mode, then press any key
/// combination (modifiers + key, or modifier alone like Fn/RightCommand).
struct KeyRecorderView: View {
    @Binding var shortcut: String
    @State private var isRecording = false
    @State private var localMonitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if isRecording {
                    Image(systemName: "record.circle")
                        .foregroundStyle(DesignTokens.Colors.terracotta)
                    Text(String(localized: "settings.scenes.editor.press_key"))
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                } else if shortcut.isEmpty {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11))
                    Text(String(localized: "settings.scenes.editor.click_to_record"))
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                } else {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11))
                    Text(HotkeyManager.displayString(for: shortcut))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(minWidth: 140)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording ? DesignTokens.Colors.terracotta.opacity(0.15) : DesignTokens.Colors.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isRecording ? DesignTokens.Colors.terracotta : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !shortcut.isEmpty {
                Button(String(localized: "common.clear"), role: .destructive) {
                    shortcut = ""
                }
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true

        // Local NSEvent monitor for keyDown events (Cmd+A, Alt+D, etc.)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleEvent(event)
            return nil  // consume the event
        }

        // Register with HotkeyTapState to capture flagsChanged events
        // (Fn, single modifier keys) that our own CGEventTap would otherwise
        // consume before reaching NSEvent local monitor.
        HotkeyTapState.shared?.recordingHandler = { keyCode, flagsRaw in
            DispatchQueue.main.async {
                handleModifierFromTap(keyCode: keyCode, flagsRaw: flagsRaw)
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        HotkeyTapState.shared?.recordingHandler = nil
    }

    /// Handle modifier event forwarded from HotkeyTapState's CGEventTap.
    private func handleModifierFromTap(keyCode: UInt16, flagsRaw: UInt64) {
        guard isRecording else { return }
        if let name = modifierOnlyNameFromRaw(keyCode: keyCode, flagsRaw: flagsRaw) {
            shortcut = name
            stopRecording()
        }
    }

    private func modifierOnlyNameFromRaw(keyCode: UInt16, flagsRaw: UInt64) -> String? {
        // Only trigger on DOWN (flag is set). Release events are ignored.
        let hasCmd = (flagsRaw & 0x100000) != 0
        let hasOpt = (flagsRaw & 0x80000) != 0
        let hasShift = (flagsRaw & 0x20000) != 0
        let hasCtrl = (flagsRaw & 0x40000) != 0
        let hasFn = (flagsRaw & 0x800000) != 0

        switch keyCode {
        case 63: return hasFn ? "Fn" : nil
        case 54: return hasCmd ? "RightCommand" : nil
        case 55: return hasCmd ? "LeftCommand" : nil
        case 61: return hasOpt ? "RightOption" : nil
        case 58: return hasOpt ? "LeftOption" : nil
        case 60: return hasShift ? "RightShift" : nil
        case 56: return hasShift ? "LeftShift" : nil
        case 62: return hasCtrl ? "RightControl" : nil
        case 59: return hasCtrl ? "LeftControl" : nil
        default: return nil
        }
    }

    private func handleEvent(_ event: NSEvent) {
        // Escape cancels recording
        if event.type == .keyDown && event.keyCode == 53 {
            stopRecording()
            return
        }

        if event.type == .keyDown {
            let combo = formatKeyDown(event)
            if !combo.isEmpty {
                shortcut = combo
                stopRecording()
            }
        } else if event.type == .flagsChanged {
            // Modifier-alone keys: Fn (63), right Command (54), etc.
            if let modifierName = modifierOnlyName(event: event) {
                shortcut = modifierName
                stopRecording()
            }
        }
    }

    /// Format a keyDown event as "Cmd+Shift+A" style string.
    private func formatKeyDown(_ event: NSEvent) -> String {
        var parts: [String] = []
        let mods = event.modifierFlags

        if mods.contains(.command) { parts.append("Cmd") }
        if mods.contains(.option) { parts.append("Alt") }
        if mods.contains(.control) { parts.append("Control") }
        if mods.contains(.shift) { parts.append("Shift") }

        guard let keyName = keyName(for: event.keyCode) else { return "" }
        parts.append(keyName)

        return parts.joined(separator: "+")
    }

    /// Detect if a flagsChanged event is a single modifier key press (like Fn, RightCommand).
    /// Returns the hotkey string or nil if it's a release or a regular modifier.
    private func modifierOnlyName(event: NSEvent) -> String? {
        let keyCode = event.keyCode
        let flags = event.modifierFlags

        // Fn key (0x3F / 63)
        if keyCode == 63 && flags.contains(.function) {
            return "Fn"
        }

        // Right Command (54) — check right-command bit via raw flags
        // Left Command (55)
        if keyCode == 54 && flags.contains(.command) {
            return "RightCommand"
        }
        if keyCode == 55 && flags.contains(.command) {
            return "LeftCommand"
        }

        // Right Option (61), Left Option (58)
        if keyCode == 61 && flags.contains(.option) {
            return "RightOption"
        }
        if keyCode == 58 && flags.contains(.option) {
            return "LeftOption"
        }

        // Right Shift (60), Left Shift (56)
        if keyCode == 60 && flags.contains(.shift) {
            return "RightShift"
        }
        if keyCode == 56 && flags.contains(.shift) {
            return "LeftShift"
        }

        // Right Control (62), Left Control (59)
        if keyCode == 62 && flags.contains(.control) {
            return "RightControl"
        }
        if keyCode == 59 && flags.contains(.control) {
            return "LeftControl"
        }

        return nil
    }

    /// Map virtual keycodes to our shortcut string format.
    private func keyName(for keyCode: UInt16) -> String? {
        let map: [UInt16: String] = [
            0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E",
            0x03: "F", 0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J",
            0x28: "K", 0x25: "L", 0x2E: "M", 0x2D: "N", 0x1F: "O",
            0x23: "P", 0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T",
            0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X", 0x10: "Y",
            0x06: "Z",
            0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5",
            0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
            0x31: "Space", 0x24: "Return", 0x30: "Tab", 0x33: "Delete",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        ]
        return map[keyCode]
    }
}
