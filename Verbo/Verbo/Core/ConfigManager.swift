import Foundation
import Observation

@Observable
@MainActor
final class ConfigManager {
    private(set) var config: AppConfig = .default
    let configFileURL: URL

    init(directory: URL? = nil) {
        let baseDir: URL
        if let directory {
            baseDir = directory
        } else {
            baseDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".verbo", isDirectory: true)
        }
        configFileURL = baseDir.appendingPathComponent("config.json")
    }

    func load() {
        // First launch: copy the bundled default-config.json (shipped inside
        // the .app bundle) to ~/.verbo/config.json so users start with a
        // populated scene list / prompts rather than built-in hardcoded
        // presets. Secrets (API keys, URLs) are stripped from the bundled
        // template so the user still has to fill them in.
        if !FileManager.default.fileExists(atPath: configFileURL.path) {
            seedFromBundledDefaultIfAvailable()
        }

        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            config = .default
            return
        }
        do {
            let data = try Data(contentsOf: configFileURL)
            let decoder = JSONDecoder()
            config = try decoder.decode(AppConfig.self, from: data)
        } catch {
            config = .default
        }
    }

    /// Copy the `default-config.json` resource bundled into the .app into
    /// `~/.verbo/config.json` on first launch. Silently no-ops if the
    /// resource is missing or the target already exists.
    private func seedFromBundledDefaultIfAvailable() {
        guard let bundled = Bundle.main.url(forResource: "default-config", withExtension: "json") else {
            Log.config.info("No bundled default-config.json; falling back to built-in defaults")
            return
        }
        do {
            let dir = configFileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true
                )
            }
            try FileManager.default.copyItem(at: bundled, to: configFileURL)
            Log.config.info("Seeded config from bundled default-config.json")
        } catch {
            Log.config.error("Failed to seed default config: \(error.localizedDescription, privacy: .public)")
        }
    }

    func update(_ newConfig: AppConfig) {
        config = newConfig
    }

    func save() throws {
        let dir = configFileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        let tempURL = dir.appendingPathComponent(UUID().uuidString + ".tmp")
        try data.write(to: tempURL, options: .atomic)
        _ = try FileManager.default.replaceItemAt(configFileURL, withItemAt: tempURL)
    }

    func getSTTProviderConfig(_ name: String) -> STTProviderConfig? {
        config.providers.stt[name]
    }

    func getLLMProviderConfig(_ name: String) -> LLMProviderConfig? {
        config.providers.llm[name]
    }

    func getScene(_ id: String) -> Scene? {
        config.scenes.first { $0.id == id }
    }

    func defaultScene() -> Scene? {
        getScene(config.defaultScene)
    }
}
