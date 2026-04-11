import Foundation
import Observation

@Observable
@MainActor
final class HistoryManager {
    private(set) var records: [HistoryRecord] = []
    private let fileURL: URL

    init(directory: URL? = nil) {
        let baseDir: URL
        if let directory {
            baseDir = directory
        } else {
            baseDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".verbo", isDirectory: true)
        }
        fileURL = baseDir.appendingPathComponent("history.json")
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            records = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = try decoder.decode([HistoryRecord].self, from: data)
        } catch {
            records = []
        }
    }

    func add(_ record: HistoryRecord) {
        records = [record] + records
    }

    func save() throws {
        let dir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(records)
        try data.write(to: fileURL, options: .atomic)
    }

    func search(query: String) -> [HistoryRecord] {
        guard !query.isEmpty else { return records }
        let lowercasedQuery = query.lowercased()
        return records.filter { record in
            record.finalText.lowercased().contains(lowercasedQuery)
                || record.originalText.lowercased().contains(lowercasedQuery)
                || record.sceneName.lowercased().contains(lowercasedQuery)
        }
    }

    func filter(byScene sceneId: String) -> [HistoryRecord] {
        records.filter { $0.sceneId == sceneId }
    }

    func clearAll() {
        records = []
    }

    func pruneOlderThan(days: Int) {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -days,
            to: Date()
        ) ?? Date()
        records = records.filter { $0.timestamp >= cutoff }
    }
}
