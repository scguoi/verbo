import Foundation

// MARK: - Output Mode

public enum OutputMode: String, Codable, Sendable {
    case simulate
    case clipboard
}

// MARK: - UI Language

public enum UILanguage: String, Codable, Sendable {
    case system
    case zh
    case en
}

// MARK: - STT Provider Config

public struct STTProviderConfig: Codable, Equatable, Sendable {
    public var appId: String
    public var apiKey: String
    public var apiSecret: String
    public var enabledLangs: [String]

    public init(
        appId: String = "",
        apiKey: String = "",
        apiSecret: String = "",
        enabledLangs: [String] = ["zh", "en"]
    ) {
        self.appId = appId
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.enabledLangs = enabledLangs
    }
}

// MARK: - LLM Provider Config

public struct LLMProviderConfig: Codable, Equatable, Sendable {
    public var apiKey: String
    public var model: String
    public var baseUrl: String

    public init(
        apiKey: String = "",
        model: String = "gpt-4o-mini",
        baseUrl: String = "https://api.openai.com/v1"
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseUrl = baseUrl
    }
}

// MARK: - Providers Config

public struct ProvidersConfig: Codable, Equatable, Sendable {
    public var stt: [String: STTProviderConfig]
    public var llm: [String: LLMProviderConfig]

    public init(
        stt: [String: STTProviderConfig] = ["iflytek": STTProviderConfig()],
        llm: [String: LLMProviderConfig] = ["openai": LLMProviderConfig()]
    ) {
        self.stt = stt
        self.llm = llm
    }
}

// MARK: - General Config

public struct GeneralConfig: Codable, Equatable, Sendable {
    public var outputMode: OutputMode
    public var autoCollapseDelay: Double
    public var copyOnDismiss: Bool
    public var launchAtStartup: Bool
    public var uiLanguage: UILanguage
    public var historyRetentionDays: Int?
    public var showTranscriptPreview: Bool

    public init(
        outputMode: OutputMode = .simulate,
        autoCollapseDelay: Double = 1.5,
        copyOnDismiss: Bool = true,
        launchAtStartup: Bool = false,
        uiLanguage: UILanguage = .system,
        historyRetentionDays: Int? = 90,
        showTranscriptPreview: Bool = true
    ) {
        self.outputMode = outputMode
        self.autoCollapseDelay = autoCollapseDelay
        self.copyOnDismiss = copyOnDismiss
        self.launchAtStartup = launchAtStartup
        self.uiLanguage = uiLanguage
        self.historyRetentionDays = historyRetentionDays
        self.showTranscriptPreview = showTranscriptPreview
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputMode = try container.decodeIfPresent(OutputMode.self, forKey: .outputMode) ?? .simulate
        autoCollapseDelay = try container.decodeIfPresent(Double.self, forKey: .autoCollapseDelay) ?? 1.5
        copyOnDismiss = try container.decodeIfPresent(Bool.self, forKey: .copyOnDismiss) ?? true
        launchAtStartup = try container.decodeIfPresent(Bool.self, forKey: .launchAtStartup) ?? false
        uiLanguage = try container.decodeIfPresent(UILanguage.self, forKey: .uiLanguage) ?? .system
        historyRetentionDays = try container.decodeIfPresent(Int.self, forKey: .historyRetentionDays) ?? 90
        showTranscriptPreview = try container.decodeIfPresent(Bool.self, forKey: .showTranscriptPreview) ?? true
    }
}

// MARK: - App Config

public struct AppConfig: Codable, Equatable, Sendable {
    public var version: Int
    public var defaultScene: String
    public var scenes: [Scene]
    public var providers: ProvidersConfig
    public var general: GeneralConfig

    public init(
        version: Int = 1,
        defaultScene: String = "dictate",
        scenes: [Scene] = Scene.presets,
        providers: ProvidersConfig = ProvidersConfig(),
        general: GeneralConfig = GeneralConfig()
    ) {
        self.version = version
        self.defaultScene = defaultScene
        self.scenes = scenes
        self.providers = providers
        self.general = general
    }

    // Custom decode so legacy config.json with a "globalHotkey" field still
    // loads cleanly — the field is simply ignored.
    private enum CodingKeys: String, CodingKey {
        case version, defaultScene, scenes, providers, general
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.defaultScene = try c.decodeIfPresent(String.self, forKey: .defaultScene) ?? "dictate"
        self.scenes = try c.decodeIfPresent([Scene].self, forKey: .scenes) ?? Scene.presets
        self.providers = try c.decodeIfPresent(ProvidersConfig.self, forKey: .providers) ?? ProvidersConfig()
        self.general = try c.decodeIfPresent(GeneralConfig.self, forKey: .general) ?? GeneralConfig()
    }

    public static let `default` = AppConfig()
}
