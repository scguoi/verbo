import Foundation
import Observation

// MARK: - DateGroup

struct DateGroup: Identifiable {
    let id: String
    let label: String
    let records: [HistoryRecord]
}

// MARK: - HistoryViewModel

@Observable
@MainActor
final class HistoryViewModel {

    // MARK: - Properties

    private(set) var historyManager: HistoryManager
    var searchQuery: String = ""
    var selectedSceneFilter: String?

    // MARK: - Init

    init(historyManager: HistoryManager) {
        self.historyManager = historyManager
    }

    // MARK: - Computed

    var filteredRecords: [HistoryRecord] {
        var result = historyManager.records

        if !searchQuery.isEmpty {
            let lowered = searchQuery.lowercased()
            result = result.filter { record in
                record.finalText.lowercased().contains(lowered)
                    || record.originalText.lowercased().contains(lowered)
                    || record.sceneName.lowercased().contains(lowered)
            }
        }

        if let sceneId = selectedSceneFilter {
            result = result.filter { $0.sceneId == sceneId }
        }

        return result
    }

    var groupedRecords: [DateGroup] {
        let calendar = Calendar.current
        let now = Date()

        var todayRecords: [HistoryRecord] = []
        var yesterdayRecords: [HistoryRecord] = []
        var earlierRecords: [HistoryRecord] = []

        for record in filteredRecords {
            if calendar.isDateInToday(record.timestamp) {
                todayRecords.append(record)
            } else if calendar.isDateInYesterday(record.timestamp) {
                yesterdayRecords.append(record)
            } else {
                earlierRecords.append(record)
            }
        }

        // Suppress unused variable warning
        _ = now

        var groups: [DateGroup] = []
        if !todayRecords.isEmpty {
            groups.append(DateGroup(id: "today", label: String(localized: "history.group.today"), records: todayRecords))
        }
        if !yesterdayRecords.isEmpty {
            groups.append(DateGroup(id: "yesterday", label: String(localized: "history.group.yesterday"), records: yesterdayRecords))
        }
        if !earlierRecords.isEmpty {
            groups.append(DateGroup(id: "earlier", label: String(localized: "history.group.earlier"), records: earlierRecords))
        }
        return groups
    }

    var availableScenes: [(id: String, name: String)] {
        var seen: Set<String> = []
        var result: [(id: String, name: String)] = []
        for record in historyManager.records {
            if !seen.contains(record.sceneId) {
                seen.insert(record.sceneId)
                result.append((id: record.sceneId, name: record.sceneName))
            }
        }
        return result
    }

    // MARK: - Actions

    func clearAll() {
        historyManager.clearAll()
        try? historyManager.save()
    }
}
