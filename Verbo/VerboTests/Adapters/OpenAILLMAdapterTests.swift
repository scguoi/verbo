import Testing
import Foundation
@testable import Verbo

// MARK: - OpenAI SSE Parser Tests

@Suite("OpenAISSEParser")
struct OpenAISSEParserTests {

    @Test("Parse valid SSE data line extracts content")
    func parseValidDataLineExtractsHello() {
        let json = """
        {"id":"chatcmpl-1","object":"chat.completion.chunk","choices":[{"delta":{"content":"Hello"},"index":0}]}
        """
        let line = "data: \(json)"
        let result = OpenAISSEParser.parseContentFromLine(line)
        #expect(result == "Hello")
    }

    @Test("Parse DONE sentinel returns nil")
    func parseDoneSentinelReturnsNil() {
        let result = OpenAISSEParser.parseContentFromLine("data: [DONE]")
        #expect(result == nil)
    }

    @Test("Parse non-data line returns nil")
    func parseNonDataLineReturnsNil() {
        let result = OpenAISSEParser.parseContentFromLine(": keep-alive")
        #expect(result == nil)
    }

    @Test("Build request body has correct structure")
    func buildRequestBodyHasCorrectStructure() {
        let body = OpenAILLMAdapter.buildRequestBody(model: "gpt-4o-mini", prompt: "Say hi", stream: false)

        #expect(body["model"] as? String == "gpt-4o-mini")
        #expect(body["stream"] as? Bool == false)

        let messages = body["messages"] as? [[String: Any]]
        #expect(messages?.count == 1)

        let first = messages?.first
        #expect(first?["role"] as? String == "user")
        #expect(first?["content"] as? String == "Say hi")
    }

    @Test("Parse SSE data line with Chinese content")
    func parseDataLineWithChineseContent() {
        let json = """
        {"id":"chatcmpl-2","object":"chat.completion.chunk","choices":[{"delta":{"content":"你好"},"index":0}]}
        """
        let line = "data: \(json)"
        let result = OpenAISSEParser.parseContentFromLine(line)
        #expect(result == "你好")
    }
}
