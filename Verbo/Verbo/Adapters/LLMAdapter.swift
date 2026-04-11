import Foundation

// MARK: - LLM Adapter Protocol

protocol LLMAdapter: Sendable {
    var name: String { get }
    func complete(prompt: String) async throws -> String
    func completeStream(prompt: String) -> AsyncThrowingStream<String, Error>
}
