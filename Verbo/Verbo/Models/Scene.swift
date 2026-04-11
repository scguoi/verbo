import Foundation

// MARK: - Scene Hotkey

public struct SceneHotkey: Codable, Equatable, Sendable {
    public var toggleRecord: String?
    public var pushToTalk: String?

    public init(toggleRecord: String? = nil, pushToTalk: String? = nil) {
        self.toggleRecord = toggleRecord
        self.pushToTalk = pushToTalk
    }
}

// MARK: - Pipeline Step

public struct PipelineStep: Codable, Equatable, Sendable {
    public enum StepType: String, Codable, Sendable {
        case stt
        case llm
    }

    public var type: StepType
    public var provider: String
    public var lang: String?
    public var prompt: String?

    public init(type: StepType, provider: String, lang: String? = nil, prompt: String? = nil) {
        self.type = type
        self.provider = provider
        self.lang = lang
        self.prompt = prompt
    }
}

// MARK: - Scene

public struct Scene: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var hotkey: SceneHotkey
    public var pipeline: [PipelineStep]
    public var output: OutputMode

    public init(
        id: String,
        name: String,
        hotkey: SceneHotkey,
        pipeline: [PipelineStep],
        output: OutputMode = .simulate
    ) {
        self.id = id
        self.name = name
        self.hotkey = hotkey
        self.pipeline = pipeline
        self.output = output
    }

    // MARK: - Presets

    public static let presets: [Scene] = [
        Scene(
            id: "dictate",
            name: "语音输入",
            hotkey: SceneHotkey(toggleRecord: "Alt+D"),
            pipeline: [
                PipelineStep(type: .stt, provider: "iflytek", lang: "zh")
            ]
        ),
        Scene(
            id: "polish",
            name: "润色输入",
            hotkey: SceneHotkey(toggleRecord: "Alt+J"),
            pipeline: [
                PipelineStep(type: .stt, provider: "iflytek", lang: "zh"),
                PipelineStep(
                    type: .llm,
                    provider: "openai",
                    prompt: "请润色以下口语化文字，使其更书面化，保持原意，直接输出结果：\n{{input}}"
                )
            ]
        ),
        Scene(
            id: "translate",
            name: "中译英",
            hotkey: SceneHotkey(toggleRecord: "Alt+T"),
            pipeline: [
                PipelineStep(type: .stt, provider: "iflytek", lang: "zh"),
                PipelineStep(
                    type: .llm,
                    provider: "openai",
                    prompt: "将以下中文翻译为英文，直接输出翻译结果：\n{{input}}"
                )
            ]
        )
    ]
}
