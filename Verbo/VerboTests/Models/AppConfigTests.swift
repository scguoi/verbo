import Testing
import Foundation
@testable import Verbo

@Suite("AppConfig Tests")
struct AppConfigTests {

    @Test("Default config has version 1")
    func defaultConfigVersion() {
        let config = AppConfig.default
        #expect(config.version == 1)
    }

    @Test("Default config defaultScene is dictate")
    func defaultConfigScene() {
        let config = AppConfig.default
        #expect(config.defaultScene == "dictate")
    }

    @Test("Default config has 3 preset scenes")
    func defaultConfigSceneCount() {
        let config = AppConfig.default
        #expect(config.scenes.count == 3)
    }

    @Test("Default config globalHotkey toggleRecord is CommandOrControl+Shift+H")
    func defaultConfigHotkey() {
        let config = AppConfig.default
        #expect(config.globalHotkey.toggleRecord == "CommandOrControl+Shift+H")
    }

    @Test("Default config globalHotkey pushToTalk is CommandOrControl+Shift+G")
    func defaultConfigPushToTalk() {
        let config = AppConfig.default
        #expect(config.globalHotkey.pushToTalk == "CommandOrControl+Shift+G")
    }

    @Test("Default providers has iflytek STT provider")
    func defaultProvidersStt() {
        let config = AppConfig.default
        #expect(config.providers.stt["iflytek"] != nil)
    }

    @Test("Default providers has openai LLM provider")
    func defaultProvidersLlm() {
        let config = AppConfig.default
        #expect(config.providers.llm["openai"] != nil)
    }

    @Test("Default general config outputMode is simulate")
    func defaultGeneralOutputMode() {
        let config = AppConfig.default
        #expect(config.general.outputMode == .simulate)
    }

    @Test("Default general config autoCollapseDelay is 1.5")
    func defaultGeneralAutoCollapse() {
        let config = AppConfig.default
        #expect(config.general.autoCollapseDelay == 1.5)
    }

    @Test("Default general config launchAtStartup is false")
    func defaultGeneralLaunchAtStartup() {
        let config = AppConfig.default
        #expect(config.general.launchAtStartup == false)
    }

    @Test("Default general config uiLanguage is system")
    func defaultGeneralUiLanguage() {
        let config = AppConfig.default
        #expect(config.general.uiLanguage == .system)
    }

    @Test("Default general config historyRetentionDays is 90")
    func defaultGeneralHistoryRetention() {
        let config = AppConfig.default
        #expect(config.general.historyRetentionDays == 90)
    }

    @Test("AppConfig JSON round-trip encoding/decoding")
    func jsonRoundTrip() throws {
        let original = AppConfig.default
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppConfig.self, from: data)
        #expect(decoded == original)
    }

    @Test("AppConfig encodes to valid JSON")
    func encodesToJson() throws {
        let config = AppConfig.default
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        #expect(!data.isEmpty)
        // Verify it's valid JSON by checking we can parse it
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }

    @Test("STTProviderConfig default values")
    func sttProviderConfigDefaults() {
        let stt = STTProviderConfig()
        #expect(stt.appId == "")
        #expect(stt.apiKey == "")
        #expect(stt.apiSecret == "")
        #expect(stt.enabledLangs == ["zh", "en"])
    }

    @Test("LLMProviderConfig default values")
    func llmProviderConfigDefaults() {
        let llm = LLMProviderConfig()
        #expect(llm.apiKey == "")
        #expect(llm.model == "gpt-4o-mini")
        #expect(llm.baseUrl == "https://api.openai.com/v1")
    }

    @Test("OutputMode raw values")
    func outputModeRawValues() {
        #expect(OutputMode.simulate.rawValue == "simulate")
        #expect(OutputMode.clipboard.rawValue == "clipboard")
    }

    @Test("UILanguage raw values")
    func uiLanguageRawValues() {
        #expect(UILanguage.system.rawValue == "system")
        #expect(UILanguage.zh.rawValue == "zh")
        #expect(UILanguage.en.rawValue == "en")
    }
}
