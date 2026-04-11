import Foundation
@testable import Verbo

final class MockTextOutputService: TextOutputting, @unchecked Sendable {
    var lastOutputText: String?
    var lastOutputMode: OutputMode?
    var outputResult: HistoryRecord.OutputStatus = .inserted
    var clipboardContent: String?

    func output(text: String, mode: OutputMode) async -> HistoryRecord.OutputStatus {
        lastOutputText = text
        lastOutputMode = mode
        return outputResult
    }

    func writeToClipboard(_ text: String) {
        clipboardContent = text
    }
}
