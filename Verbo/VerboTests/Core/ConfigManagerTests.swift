import Testing
import Foundation
@testable import Verbo

@Suite("ConfigManager Tests")
struct ConfigManagerTests {

    @Test("Loads default config when no file exists")
    @MainActor
    func loadsDefaultWhenNoFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = ConfigManager(directory: tempDir)
        manager.load()

        #expect(manager.config.version == 1)
        #expect(manager.config.scenes.count == 3)
    }

    @Test("Saves and loads config round-trip")
    @MainActor
    func saveAndLoadRoundTrip() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = ConfigManager(directory: tempDir)
        manager.load()

        var updated = manager.config
        updated.defaultScene = "polish"
        manager.update(updated)
        try manager.save()

        let manager2 = ConfigManager(directory: tempDir)
        manager2.load()

        #expect(manager2.config.defaultScene == "polish")
    }

    @Test("Config file path ends with config.json")
    @MainActor
    func configFilePathEndsWithConfigJson() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = ConfigManager(directory: tempDir)
        #expect(manager.configFileURL.lastPathComponent == "config.json")
    }
}
