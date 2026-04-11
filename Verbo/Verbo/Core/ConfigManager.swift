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
