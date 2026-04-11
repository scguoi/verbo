import Foundation
import Observation

// MARK: - SettingsViewModel

@Observable
@MainActor
final class SettingsViewModel {

    // MARK: - Properties

    private(set) var configManager: ConfigManager

    var editingScene: Scene?
    var isEditingScene: Bool = false

    // MARK: - Init

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    // MARK: - Computed

    var config: AppConfig { configManager.config }

    // MARK: - Scene Operations

    func selectSceneAsDefault(_ sceneId: String) {
        let newConfig = AppConfig(
            version: config.version,
            defaultScene: sceneId,
            globalHotkey: config.globalHotkey,
            scenes: config.scenes,
            providers: config.providers,
            general: config.general
        )
        configManager.update(newConfig)
        try? configManager.save()
    }

    func startEditingScene(_ scene: Scene) {
        editingScene = scene
        isEditingScene = true
    }

    func saveEditingScene(_ updated: Scene) {
        guard let idx = config.scenes.firstIndex(where: { $0.id == updated.id }) else { return }
        var newScenes = config.scenes
        newScenes[idx] = updated
        let newConfig = AppConfig(
            version: config.version,
            defaultScene: config.defaultScene,
            globalHotkey: config.globalHotkey,
            scenes: newScenes,
            providers: config.providers,
            general: config.general
        )
        configManager.update(newConfig)
        try? configManager.save()
        editingScene = nil
        isEditingScene = false
    }

    func cancelEditingScene() {
        editingScene = nil
        isEditingScene = false
    }

    func deleteScene(_ sceneId: String) {
        let newScenes = config.scenes.filter { $0.id != sceneId }
        let newDefault = config.defaultScene == sceneId
            ? (newScenes.first?.id ?? "")
            : config.defaultScene
        let newConfig = AppConfig(
            version: config.version,
            defaultScene: newDefault,
            globalHotkey: config.globalHotkey,
            scenes: newScenes,
            providers: config.providers,
            general: config.general
        )
        configManager.update(newConfig)
        try? configManager.save()
    }

    // MARK: - Provider Operations

    func updateSTTProvider(_ name: String, _ updated: STTProviderConfig) {
        var newSTT = config.providers.stt
        newSTT[name] = updated
        let newProviders = ProvidersConfig(stt: newSTT, llm: config.providers.llm)
        let newConfig = AppConfig(
            version: config.version,
            defaultScene: config.defaultScene,
            globalHotkey: config.globalHotkey,
            scenes: config.scenes,
            providers: newProviders,
            general: config.general
        )
        configManager.update(newConfig)
        try? configManager.save()
    }

    func updateLLMProvider(_ name: String, _ updated: LLMProviderConfig) {
        var newLLM = config.providers.llm
        newLLM[name] = updated
        let newProviders = ProvidersConfig(stt: config.providers.stt, llm: newLLM)
        let newConfig = AppConfig(
            version: config.version,
            defaultScene: config.defaultScene,
            globalHotkey: config.globalHotkey,
            scenes: config.scenes,
            providers: newProviders,
            general: config.general
        )
        configManager.update(newConfig)
        try? configManager.save()
    }

    // MARK: - General Operations

    func updateGeneral(_ updated: GeneralConfig) {
        let newConfig = AppConfig(
            version: config.version,
            defaultScene: config.defaultScene,
            globalHotkey: config.globalHotkey,
            scenes: config.scenes,
            providers: config.providers,
            general: updated
        )
        configManager.update(newConfig)
        try? configManager.save()
    }
}
