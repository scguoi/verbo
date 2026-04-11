import AppKit
import CoreGraphics

// MARK: - TextOutputService

final class TextOutputService: Sendable {

    // MARK: - Public API

    /// Output text in the specified mode.
    func output(text: String, mode: OutputMode) async -> HistoryRecord.OutputStatus {
        switch mode {
        case .simulate:
            return await simulateInput(text: text)
        case .clipboard:
            writeToClipboard(text)
            return .copied
        }
    }

    // MARK: - Simulate Input

    private func simulateInput(text: String) async -> HistoryRecord.OutputStatus {
        let previousClipboard = readFromClipboard()

        if simulateWithCGEvent(text: text) {
            return .inserted
        }

        // Fallback: clipboard + Cmd+V
        writeToClipboard(text)
        _ = simulatePaste()

        // Restore original clipboard after 200ms
        try? await Task.sleep(nanoseconds: 200_000_000)
        if let previous = previousClipboard {
            writeToClipboard(previous)
        } else {
            NSPasteboard.general.clearContents()
        }

        return .inserted
    }

    // MARK: - CGEvent Simulation

    private func simulateWithCGEvent(text: String) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }

        for char in text.unicodeScalars {
            var unicodeString = [UniChar](String(char).utf16)

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else {
                return false
            }

            keyDown.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: &unicodeString)
            keyUp.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: &unicodeString)

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        return true
    }

    private func simulatePaste() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }

        // Cmd+V: keyCode 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        return true
    }

    // MARK: - Clipboard

    func writeToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func readFromClipboard() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
