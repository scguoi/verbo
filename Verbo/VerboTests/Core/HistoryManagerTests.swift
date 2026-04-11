import Testing
import Foundation
@testable import Verbo

@Suite("HistoryManager Tests")
struct HistoryManagerTests {

    private func makeRecord(finalText: String, originalText: String = "", sceneName: String = "Test Scene") -> HistoryRecord {
        HistoryRecord(
            id: UUID(),
            timestamp: Date(),
            sceneId: "test",
            sceneName: sceneName,
            originalText: originalText.isEmpty ? finalText : originalText,
            finalText: finalText,
            outputStatus: .inserted,
            pipelineSteps: ["stt"]
        )
    }

    @Test("Add record and retrieve")
    @MainActor
    func addRecordAndRetrieve() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = HistoryManager(directory: tempDir)
        let record = makeRecord(finalText: "hello world")
        manager.add(record)

        #expect(manager.records.count == 1)
        #expect(manager.records[0].finalText == "hello world")
    }

    @Test("Persist and reload")
    @MainActor
    func persistAndReload() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = HistoryManager(directory: tempDir)
        let record = makeRecord(finalText: "persisted text")
        manager.add(record)
        try manager.save()

        let manager2 = HistoryManager(directory: tempDir)
        manager2.load()

        #expect(manager2.records.count == 1)
        #expect(manager2.records[0].finalText == "persisted text")
    }

    @Test("Search filters by text")
    @MainActor
    func searchFiltersByText() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = HistoryManager(directory: tempDir)
        manager.add(makeRecord(finalText: "hello world"))
        manager.add(makeRecord(finalText: "goodbye"))

        let results = manager.search(query: "hello")

        #expect(results.count == 1)
        #expect(results[0].finalText == "hello world")
    }

    @Test("Clear all removes all records")
    @MainActor
    func clearAllRemovesAllRecords() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = HistoryManager(directory: tempDir)
        manager.add(makeRecord(finalText: "some text"))
        manager.clearAll()

        #expect(manager.records.isEmpty)
    }
}
