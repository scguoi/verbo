import Foundation

protocol AudioRecording: Sendable {
    var isRecording: Bool { get async }
    var audioLevels: [Float] { get async }
    func start() async -> AsyncStream<Data>
    func stop() async -> Data
}

protocol TextOutputting: Sendable {
    func output(text: String, mode: OutputMode) async -> HistoryRecord.OutputStatus
    func writeToClipboard(_ text: String)
}
