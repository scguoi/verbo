import Testing
import SwiftUI
@testable import Verbo

// MARK: - WaveformView Boundary Tests

@Suite("WaveformView Boundary Tests")
struct WaveformViewTests {

    @Test("WaveformView initializes with empty levels without crashing")
    func emptyLevels() {
        let view = WaveformView(levels: [])
        // Verify the view was constructed with the correct level count
        #expect(view.levels.isEmpty)
    }

    @Test("WaveformView initializes with levels exceeding 1.0 without crashing")
    func levelsExceedingOne() {
        let view = WaveformView(levels: [1.5, 2.0, 99.9])
        #expect(view.levels.count == 3)
    }

    @Test("WaveformView initializes with more levels than bars without crashing")
    func moreLevelsThanBars() {
        let levels = Array(repeating: Float(0.5), count: 100)
        let view = WaveformView(levels: levels, barCount: 13)
        #expect(view.levels.count == 100)
        #expect(view.barCount == 13)
    }
}

// MARK: - Color(hex:) Boundary Tests

@Suite("Color Hex Boundary Tests")
struct ColorHexTests {

    @Test("Color(hex:) with 0x000000 produces a color without crashing")
    func blackHex() {
        let color = Color(hex: 0x000000)
        _ = color
    }

    @Test("Color(hex:) with 0xFFFFFF produces a color without crashing")
    func whiteHex() {
        let color = Color(hex: 0xFFFFFF)
        _ = color
    }

    @Test("Color(hex:) with opacity 0.5 produces a color without crashing")
    func hexWithOpacity() {
        let color = Color(hex: 0xFFFFFF, opacity: 0.5)
        _ = color
    }
}

// MARK: - HotkeyManager.parseShortcut Boundary Tests

@Suite("HotkeyManager parseShortcut Boundary Tests")
@MainActor
struct HotkeyParseShortcutBoundaryTests {

    @Test("parseShortcut returns nil for empty string")
    func emptyString() {
        let result = HotkeyManager.parseShortcut("")
        #expect(result == nil)
    }

    @Test("parseShortcut returns nil for unknown key with emoji")
    func unknownKeyWithEmoji() {
        let result = HotkeyManager.parseShortcut("Alt+😀")
        #expect(result == nil)
    }

    @Test("parseShortcut returns non-nil for valid Alt+D with .option modifier")
    func validAltD() {
        let result = HotkeyManager.parseShortcut("Alt+D")
        #expect(result != nil)
        #expect(result?.modifiers.contains(.option) == true)
    }
}

// MARK: - HotkeyManager.displayString Boundary Tests

@Suite("HotkeyManager displayString Boundary Tests")
@MainActor
struct HotkeyDisplayStringBoundaryTests {

    @Test("displayString for RightCommand returns R⌘")
    func rightCommand() {
        let result = HotkeyManager.displayString(for: "RightCommand")
        #expect(result == "R⌘")
    }

    @Test("displayString for Alt+D returns ⌥D")
    func altD() {
        let result = HotkeyManager.displayString(for: "Alt+D")
        #expect(result == "⌥D")
    }

    @Test("displayString for CommandOrControl+Shift+H returns ⌘⇧H")
    func commandOrControlShiftH() {
        let result = HotkeyManager.displayString(for: "CommandOrControl+Shift+H")
        #expect(result == "⌘⇧H")
    }
}

// MARK: - PipelineEngine.resolveTemplate Boundary Tests

@Suite("PipelineEngine resolveTemplate Boundary Tests")
struct PipelineEngineTemplateTests {

    @Test("resolveTemplate with no placeholder returns template unchanged")
    func noPlaceholder() {
        let result = PipelineEngine.resolveTemplate("Hello world", input: "test")
        #expect(result == "Hello world")
    }

    @Test("resolveTemplate with empty input replaces placeholder with empty string")
    func emptyInput() {
        let result = PipelineEngine.resolveTemplate("Process: {{input}}", input: "")
        #expect(result == "Process: ")
    }

    @Test("resolveTemplate replaces multiple {{input}} placeholders")
    func multiplePlaceholders() {
        let result = PipelineEngine.resolveTemplate("{{input}} and {{input}}", input: "hello")
        #expect(result == "hello and hello")
    }
}
