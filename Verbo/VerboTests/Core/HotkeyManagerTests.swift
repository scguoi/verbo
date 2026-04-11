import Testing
@testable import Verbo

@Suite("HotkeyManager Tests")
@MainActor
struct HotkeyManagerTests {

    // MARK: - parseShortcut

    @Test("parseShortcut: Alt+D returns non-nil with .option modifier")
    func parseAltD() {
        let result = HotkeyManager.parseShortcut("Alt+D")
        #expect(result != nil)
        #expect(result?.modifiers.contains(.option) == true)
    }

    @Test("parseShortcut: CommandOrControl+Shift+H returns non-nil with .command and .shift")
    func parseCommandOrControlShiftH() {
        let result = HotkeyManager.parseShortcut("CommandOrControl+Shift+H")
        #expect(result != nil)
        #expect(result?.modifiers.contains(.command) == true)
        #expect(result?.modifiers.contains(.shift) == true)
    }

    @Test("parseShortcut: single letter 'a' returns non-nil with empty modifiers")
    func parseSingleLetter() {
        let result = HotkeyManager.parseShortcut("a")
        #expect(result != nil)
        #expect(result?.modifiers == [])
    }

    @Test("parseShortcut: empty string returns nil")
    func parseEmptyString() {
        let result = HotkeyManager.parseShortcut("")
        #expect(result == nil)
    }

    @Test("parseShortcut: invalid key Alt+🎤 returns nil")
    func parseInvalidKeyWithEmoji() {
        let result = HotkeyManager.parseShortcut("Alt+🎤")
        #expect(result == nil)
    }

    // MARK: - displayString

    @Test("displayString: RightCommand returns R⌘")
    func displayRightCommand() {
        let result = HotkeyManager.displayString(for: "RightCommand")
        #expect(result == "R⌘")
    }

    @Test("displayString: LeftCommand returns L⌘")
    func displayLeftCommand() {
        let result = HotkeyManager.displayString(for: "LeftCommand")
        #expect(result == "L⌘")
    }

    @Test("displayString: Alt+D returns ⌥D")
    func displayAltD() {
        let result = HotkeyManager.displayString(for: "Alt+D")
        #expect(result == "⌥D")
    }

    @Test("displayString: Shift+A returns ⇧A")
    func displayShiftA() {
        let result = HotkeyManager.displayString(for: "Shift+A")
        #expect(result == "⇧A")
    }

    @Test("displayString: Ctrl+Space returns ⌃␣")
    func displayCtrlSpace() {
        let result = HotkeyManager.displayString(for: "Ctrl+Space")
        #expect(result == "⌃␣")
    }

    @Test("displayString: Fn returns fn")
    func displayFn() {
        let result = HotkeyManager.displayString(for: "Fn")
        #expect(result == "fn")
    }

    @Test("displayString: unknown 'xyz' returns XYZ (uppercased)")
    func displayUnknown() {
        let result = HotkeyManager.displayString(for: "xyz")
        #expect(result == "XYZ")
    }
}
