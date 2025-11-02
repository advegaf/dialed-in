import Foundation

struct SessionRecord: Identifiable, Codable {
    let id: UUID
    let startedAt: Date
    let durationMinutes: Int
    let mode: FocusSessionMode
    let appNames: [String]
}

final class SessionHistoryStore {
    private let storageKey = "dialedIn.sessionHistory"
    private let syncEnabledKey = "dialedIn.syncAcrossDevices"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let defaults = UserDefaults.standard
    private weak var cloudSyncManager: CloudSyncManager?

    init(cloudSyncManager: CloudSyncManager? = nil) {
        self.cloudSyncManager = cloudSyncManager
        encoder.outputFormatting = [.prettyPrinted]
    }

    func load() -> [SessionRecord] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }

        do {
            return try decoder.decode([SessionRecord].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ records: [SessionRecord], propagateToCloud: Bool = true) {
        do {
            let data = try encoder.encode(records)
            defaults.set(data, forKey: storageKey)

            if propagateToCloud {
                cloudSyncManager?.setSessionHistory(records, enabled: syncEnabled)
            }
        } catch {
            // Swallow errors for now; consider logging to analytics in future.
        }
    }

    func merge(with remoteRecords: [SessionRecord]) -> [SessionRecord] {
        var merged: [UUID: SessionRecord] = [:]
        let localRecords = load()

        for record in localRecords {
            merged[record.id] = record
        }

        for record in remoteRecords {
            merged[record.id] = record
        }

        let sorted = merged.values.sorted { lhs, rhs in
            lhs.startedAt > rhs.startedAt
        }

        save(sorted, propagateToCloud: false)
        return sorted
    }

    private var syncEnabled: Bool {
        defaults.bool(forKey: syncEnabledKey)
    }
}
