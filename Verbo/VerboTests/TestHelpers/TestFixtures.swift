import Foundation
@testable import Verbo

enum TestFixtures {
    static func config(
        sttAppId: String = "test-app",
        sttApiKey: String = "test-key",
        sttApiSecret: String = "test-secret",
        llmApiKey: String = "test-llm-key"
    ) -> AppConfig {
        AppConfig(
            providers: ProvidersConfig(
                stt: ["iflytek": STTProviderConfig(appId: sttAppId, apiKey: sttApiKey, apiSecret: sttApiSecret)],
                llm: ["openai": LLMProviderConfig(apiKey: llmApiKey)]
            )
        )
    }

    static func scene(id: String = "test", name: String = "Test", steps: [PipelineStep.StepType] = [.stt]) -> Scene {
        Scene(
            id: id,
            name: name,
            hotkey: SceneHotkey(),
            pipeline: steps.map { type in
                switch type {
                case .stt: PipelineStep(type: .stt, provider: "iflytek", lang: "zh")
                case .llm: PipelineStep(type: .llm, provider: "openai", prompt: "Process: {{input}}")
                }
            }
        )
    }

    static func historyRecord(
        finalText: String = "测试文本",
        status: HistoryRecord.OutputStatus = .inserted
    ) -> HistoryRecord {
        HistoryRecord(
            id: UUID(),
            timestamp: Date(),
            sceneId: "test",
            sceneName: "Test",
            originalText: finalText,
            finalText: finalText,
            outputStatus: status,
            pipelineSteps: ["stt:iflytek"]
        )
    }

    static let sampleAudioChunk = Data(repeating: 0, count: 1280)

    static let emptyAudioStream: AsyncStream<Data> = AsyncStream { $0.finish() }

    static func audioStream(chunks: [Data] = [sampleAudioChunk]) -> AsyncStream<Data> {
        AsyncStream { continuation in
            for chunk in chunks { continuation.yield(chunk) }
            continuation.finish()
        }
    }

    static let iflytekSuccessJSON = """
    {"code":0,"message":"success","data":{"result":{"ws":[{"cw":[{"w":"你好","sc":0}]}],"sn":1,"ls":false,"pgs":"apd"},"status":1}}
    """

    static let iflytekFinalJSON = """
    {"code":0,"message":"success","data":{"result":{"ws":[{"cw":[{"w":"世界","sc":0}]}],"sn":2,"ls":true,"pgs":"apd"},"status":2}}
    """

    static let iflytekErrorJSON = """
    {"code":10165,"message":"invalid handle","data":null}
    """
}
