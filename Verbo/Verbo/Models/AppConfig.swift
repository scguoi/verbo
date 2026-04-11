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

// MARK: - Global Hotkey

public struct GlobalHotkey: Codable, Equatable, Sendable {
    public var toggleRecord: String
    public var pushToTalk: String?

    public init(
        toggleRecord: String = "CommandOrControl+Shift+H",
        pushToTalk: String? = "CommandOrControl+Shift+G"
    ) {
        self.toggleRecord = toggleRecord
        self.pushToTalk = pushToTalk
    }
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

    public init(
        outputMode: OutputMode = .simulate,
        autoCollapseDelay: Double = 1.5,
        copyOnDismiss: Bool = true,
        launchAtStartup: Bool = false,
        uiLanguage: UILanguage = .system,
        historyRetentionDays: Int? = 90
    ) {
        self.outputMode = outputMode
        self.autoCollapseDelay = autoCollapseDelay
        self.copyOnDismiss = copyOnDismiss
        self.launchAtStartup = launchAtStartup
        self.uiLanguage = uiLanguage
        self.historyRetentionDays = historyRetentionDays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputMode = try container.decodeIfPresent(OutputMode.self, forKey: .outputMode) ?? .simulate
        autoCollapseDelay = try container.decodeIfPresent(Double.self, forKey: .autoCollapseDelay) ?? 1.5
        copyOnDismiss = try container.decodeIfPresent(Bool.self, forKey: .copyOnDismiss) ?? true
        launchAtStartup = try container.decodeIfPresent(Bool.self, forKey: .launchAtStartup) ?? false
        uiLanguage = try container.decodeIfPresent(UILanguage.self, forKey: .uiLanguage) ?? .system
        historyRetentionDays = try container.decodeIfPresent(Int.self, forKey: .historyRetentionDays) ?? 90
    }
}

// MARK: - App Config

public struct AppConfig: Codable, Equatable, Sendable {
    public var version: Int
    public var defaultScene: String
    public var globalHotkey: GlobalHotkey
    public var scenes: [Scene]
    public var providers: ProvidersConfig
    public var general: GeneralConfig

    public init(
        version: Int = 1,
        defaultScene: String = "dictate",
        globalHotkey: GlobalHotkey = GlobalHotkey(),
        scenes: [Scene] = Scene.presets,
        providers: ProvidersConfig = ProvidersConfig(),
        general: GeneralConfig = GeneralConfig()
    ) {
        self.version = version
        self.defaultScene = defaultScene
        self.globalHotkey = globalHotkey
        self.scenes = scenes
        self.providers = providers
        self.general = general
    }

    public static let `default` = AppConfig()
}
