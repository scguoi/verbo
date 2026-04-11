import Foundation

/// Protocol defining the interface for Speech-to-Text adapters.
protocol STTAdapter: Sendable {
    var name: String { get }
    var supportsStreaming: Bool { get }

    /// Transcribes audio data in a single batch request.
    func transcribe(audio: Data, lang: String) async throws -> String

    /// Transcribes an audio stream, yielding partial results as they arrive.
    func transcribeStream(audioStream: AsyncStream<Data>, lang: String) -> AsyncThrowingStream<String, Error>
}
