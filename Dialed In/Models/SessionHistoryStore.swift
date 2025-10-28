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
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted]
    }

    func load() -> [SessionRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }

        do {
            return try decoder.decode([SessionRecord].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ records: [SessionRecord]) {
        do {
            let data = try encoder.encode(records)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Swallow errors for now; consider logging to analytics in future.
        }
    }
}
