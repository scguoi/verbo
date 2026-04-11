import Testing
import AppKit
@testable import Verbo

// MARK: - TextOutputService Tests

@Suite("TextOutputService")
struct TextOutputServiceTests {

    @Test("Clipboard write and read round-trip")
    func clipboardWriteReadRoundTrip() {
        let service = TextOutputService()
        let testText = "Hello, 你好世界"

        service.writeToClipboard(testText)
        let result = service.readFromClipboard()

        #expect(result == testText)
    }

    @Test("Output mode clipboard writes to clipboard and returns copied status")
    func outputModeClipboardWritesAndReturnsCopied() async {
        let service = TextOutputService()
        let testText = "Test output text"

        let status = await service.output(text: testText, mode: .clipboard)

        #expect(status == .copied)
        #expect(service.readFromClipboard() == testText)
    }
}
