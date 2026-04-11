import Testing
import Foundation
@testable import Verbo

// MARK: - Helper: Make Audio Stream

private func makeAudioStream(chunks: [Data] = [Data()]) -> AsyncStream<Data> {
    AsyncStream { continuation in
        Task {
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}

// MARK: - Tests

@Suite("PipelineEngine Tests")
struct PipelineEngineTests {

    @Test("STT-only pipeline produces transcribed text")
    func sttOnlyPipeline() async throws {
        let engine = PipelineEngine()
        let sttAdapter = MockSTTAdapter()
        sttAdapter.transcribeResult = "你好世界"

        let steps = [PipelineStep(type: .stt, provider: "mock-stt", lang: "zh")]
        let audioStream = makeAudioStream()

        let stream = await engine.execute(
            steps: steps,
            audioStream: audioStream,
            getSTT: { name in name == "mock-stt" ? sttAdapter : nil },
            getLLM: { _ in nil }
        )

        var lastState: PipelineState? = nil
        for try await state in stream {
            lastState = state
        }

        if case .done(let result, _) = lastState {
            #expect(result == "你好世界")
        } else {
            Issue.record("Expected .done state, got \(String(describing: lastState))")
        }
    }

    @Test("STT + LLM pipeline produces processed text")
    func sttPlusLLMPipeline() async throws {
        let engine = PipelineEngine()
        let sttAdapter = MockSTTAdapter()
        sttAdapter.transcribeResult = "我觉得还行"

        let llmAdapter = MockLLMAdapter()
        llmAdapter.completeResult = "我认为可以"

        let steps = [
            PipelineStep(type: .stt, provider: "mock-stt", lang: "zh"),
            PipelineStep(type: .llm, provider: "mock-llm", prompt: "润色：{{input}}")
        ]
        let audioStream = makeAudioStream()

        let stream = await engine.execute(
            steps: steps,
            audioStream: audioStream,
            getSTT: { name in name == "mock-stt" ? sttAdapter : nil },
            getLLM: { name in name == "mock-llm" ? llmAdapter : nil }
        )

        var lastState: PipelineState? = nil
        for try await state in stream {
            lastState = state
        }

        if case .done(let result, let source) = lastState {
            #expect(result == "我认为可以")
            #expect(source == "我觉得还行")
        } else {
            Issue.record("Expected .done state, got \(String(describing: lastState))")
        }
    }

    @Test("Template replacement substitutes input")
    func templateReplacement() async throws {
        let result = PipelineEngine.resolveTemplate("Translate: {{input}}", input: "你好")
        #expect(result == "Translate: 你好")
    }
}
