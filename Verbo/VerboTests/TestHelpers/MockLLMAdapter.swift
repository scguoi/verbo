import Foundation
@testable import Verbo

final class MockLLMAdapter: LLMAdapter, @unchecked Sendable {
    let name = "mock-llm"
    var completeResult = "Polished text"
    var shouldThrow: Error?
    var lastPrompt: String?

    func complete(prompt: String) async throws -> String {
        lastPrompt = prompt
        if let error = shouldThrow { throw error }
        return completeResult
    }

    func completeStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        lastPrompt = prompt
        let result = completeResult
        let error = shouldThrow
        return AsyncThrowingStream { continuation in
            Task {
                if let error { continuation.finish(throwing: error); return }
                for (i, _) in result.enumerated() {
                    continuation.yield(String(result.prefix(i + 1)))
                }
                continuation.finish()
            }
        }
    }
}
