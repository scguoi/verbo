import Foundation
import Observation

// MARK: - SaveToast

/// Transient feedback shown in the Settings window after a persist attempt.
struct SaveToast: Equatable, Identifiable {
    let id = UUID()
    let isSuccess: Bool
    let message: String
}

// MARK: - SettingsViewModel

@Observable
@MainActor
final class SettingsViewModel {

    // MARK: - Properties

    private(set) var configManager: ConfigManager

    var editingScene: Scene?
    var isEditingScene: Bool = false

    /// Latest save result. Views observe this and render a transient toast.
    var saveToast: SaveToast?
    private var toastDismissTask: Task<Void, Never>?

    // MARK: - Init

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    // MARK: - Computed

    var config: AppConfig { configManager.config }

    // MARK: - Persistence Helper

    /// Persist current config and publish a localized success/error toast.
    /// All save operations in this view model go through this helper so
    /// every settings-screen change gets consistent user feedback.
    private func persist() {
        do {
            try configManager.save()
            showToast(success: true,
                      messageKey: "settings.save.success")
        } catch {
            Log.config.error("Settings save failed: \(error.localizedDescription, privacy: .public)")
            showToast(success: false,
                      messageKey: "settings.save.failure")
        }
    }

    private func showToast(success: Bool, messageKey: String.LocalizationValue) {
        saveToast = SaveToast(
            isSuccess: success,
            message: String(localized: messageKey)
        )
        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.saveToast = nil }
        }
    }

    // MARK: - Scene Operations

    func selectSceneAsDefault(_ sceneId: String) {
        let newConfig = AppConfig(
            version: config.version,
            defaultScene: sceneId,
            scenes: config.scenes,
            providers: config.providers,
            general: config.general
        )
        configManager.update(newConfig)
        persist()
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
            scenes: newScenes,
            providers: config.providers,
            general: config.general
        )
        configManager.update(newConfig)
        persist()
        editingScene = nil
        isEditingScene = false
    }

    func cancelEditingScene() {
        editingScene = nil
        isEditingScene = false
    }

    /// Create a new scene with default values and return it so the UI can
    /// immediately open it in the editor.
    @discardableResult
    func createScene() -> Scene {
        let newId = "scene-\(Int(Date().timeIntervalSince1970))"
        let newScene = Scene(
            id: newId,
            name: String(localized: "settings.scenes.new_scene_name"),
            hotkey: SceneHotkey(),
            pipeline: [PipelineStep(type: .stt, provider: "iflytek", lang: "zh")],
            output: .simulate
        )
        let newConfig = AppConfig(
            version: config.version,
            defaultScene: config.defaultScene,
            scenes: config.scenes + [newScene],
            providers: config.providers,
            general: config.general
        )
        configManager.update(newConfig)
        persist()
        return newScene
    }

    func deleteScene(_ sceneId: String) {
        let newScenes = config.scenes.filter { $0.id != sceneId }
        let newDefault = config.defaultScene == sceneId
            ? (newScenes.first?.id ?? "")
            : config.defaultScene
        let newConfig = AppConfig(
            version: config.version,
            defaultScene: newDefault,
            scenes: newScenes,
            providers: config.providers,
            general: config.general
        )
        configManager.update(newConfig)
        persist()
    }

    // MARK: - Provider Operations

    func updateSTTProvider(_ name: String, _ updated: STTProviderConfig) {
        var newSTT = config.providers.stt
        newSTT[name] = updated
        let newProviders = ProvidersConfig(stt: newSTT, llm: config.providers.llm)
        let newConfig = AppConfig(
            version: config.version,
            defaultScene: config.defaultScene,
            scenes: config.scenes,
            providers: newProviders,
            general: config.general
        )
        configManager.update(newConfig)
        persist()
    }

    func updateLLMProvider(_ name: String, _ updated: LLMProviderConfig) {
        var newLLM = config.providers.llm
        newLLM[name] = updated
        let newProviders = ProvidersConfig(stt: config.providers.stt, llm: newLLM)
        let newConfig = AppConfig(
            version: config.version,
            defaultScene: config.defaultScene,
            scenes: config.scenes,
            providers: newProviders,
            general: config.general
        )
        configManager.update(newConfig)
        persist()
    }

    // MARK: - General Operations

    func updateGeneral(_ updated: GeneralConfig) {
        let newConfig = AppConfig(
            version: config.version,
            defaultScene: config.defaultScene,
            scenes: config.scenes,
            providers: config.providers,
            general: updated
        )
        configManager.update(newConfig)
        persist()
    }
}
