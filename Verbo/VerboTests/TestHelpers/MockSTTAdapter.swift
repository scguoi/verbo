import Foundation
@testable import Verbo

final class MockSTTAdapter: STTAdapter, @unchecked Sendable {
    let name = "mock-stt"
    let supportsStreaming = true
    var transcribeResult = "你好世界"
    var shouldThrow: Error?
    var transcribeCallCount = 0

    func transcribe(audio: Data, lang: String) async throws -> String {
        transcribeCallCount += 1
        if let error = shouldThrow { throw error }
        return transcribeResult
    }

    func transcribeStream(audioStream: AsyncStream<Data>, lang: String) -> AsyncThrowingStream<String, Error> {
        let result = transcribeResult
        let error = shouldThrow
        return AsyncThrowingStream { continuation in
            Task {
                for await _ in audioStream {}
                if let error { continuation.finish(throwing: error); return }
                continuation.yield(result)
                continuation.finish()
            }
        }
    }
}
