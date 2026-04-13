import Testing
import Foundation
@testable import Verbo

@Suite("AppConfig JSON Compatibility Tests")
struct AppConfigCompatibilityTests {

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - GeneralConfig

    @Test("GeneralConfig decodes with missing copyOnDismiss defaults to true")
    func generalConfigMissingCopyOnDismiss() throws {
        let json = """
        {"outputMode":"simulate","autoCollapseDelay":1.5,"launchAtStartup":false,"uiLanguage":"system"}
        """
        let data = json.data(using: .utf8)!
        let config = try decoder.decode(GeneralConfig.self, from: data)
        #expect(config.copyOnDismiss == true)
    }

    @Test("GeneralConfig decodes with all fields missing uses all defaults")
    func generalConfigAllFieldsMissing() throws {
        let json = "{}"
        let data = json.data(using: .utf8)!
        let config = try decoder.decode(GeneralConfig.self, from: data)
        #expect(config.outputMode == .simulate)
        #expect(config.autoCollapseDelay == 1.5)
        #expect(config.copyOnDismiss == true)
        #expect(config.launchAtStartup == false)
        #expect(config.uiLanguage == .system)
    }

    // MARK: - AppConfig

    @Test("AppConfig decodes successfully when all required fields are present")
    func appConfigWithAllRequiredFields() throws {
        let json = """
        {
            "version": 1,
            "defaultScene": "dictate",
            "globalHotkey": {"toggleRecord": "Alt+D"},
            "scenes": [],
            "providers": {"stt": {}, "llm": {}},
            "general": {}
        }
        """
        let data = json.data(using: .utf8)!
        let config = try decoder.decode(AppConfig.self, from: data)
        #expect(config.version == 1)
        // general uses GeneralConfig defaults (has custom init(from:))
        #expect(config.general.copyOnDismiss == true)
    }

    @Test("Scene decodes with hotkey field having nil toggleRecord")
    func sceneDecodeMissingHotkeyFields() throws {
        let json = """
        {
            "id": "test",
            "name": "Test",
            "hotkey": {},
            "pipeline": [],
            "output": "simulate"
        }
        """
        let data = json.data(using: .utf8)!
        let scene = try decoder.decode(Scene.self, from: data)
        #expect(scene.id == "test")
        #expect(scene.hotkey.toggleRecord == nil)
    }

    @Test("AppConfig ignores unknown extra fields")
    func appConfigIgnoresExtraFields() throws {
        let json = """
        {
            "version": 1,
            "defaultScene": "dictate",
            "globalHotkey": {"toggleRecord": "Alt+D"},
            "scenes": [],
            "providers": {"stt": {}, "llm": {}},
            "general": {},
            "unknownField": "should be ignored",
            "anotherUnknown": 42
        }
        """
        let data = json.data(using: .utf8)!
        let config = try decoder.decode(AppConfig.self, from: data)
        #expect(config.version == 1)
    }

    @Test("Full AppConfig encode-decode round trip preserves equality")
    func appConfigRoundTrip() throws {
        let original = AppConfig.default
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AppConfig.self, from: data)
        #expect(decoded == original)
    }

    @Test("GeneralConfig with copyOnDismiss=false round trips correctly")
    func generalConfigCopyOnDismissFalseRoundTrip() throws {
        let original = GeneralConfig(copyOnDismiss: false)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GeneralConfig.self, from: data)
        #expect(decoded.copyOnDismiss == false)
        #expect(decoded == original)
    }

}
