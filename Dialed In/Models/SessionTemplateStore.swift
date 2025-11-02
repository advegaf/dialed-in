import Foundation
import Combine

struct SessionTemplate: Identifiable, Codable, Equatable {
    struct Schedule: Codable, Equatable {
        enum Frequency: String, Codable, CaseIterable {
            case once
            case daily
            case weekly
        }

        var frequency: Frequency
        var time: DateComponents
        var weekdays: [Int]?
        var reminderMinutesBefore: Int?
    }

    let id: UUID
    var name: String
    var appIDs: [String]
    var mode: FocusSessionMode
    var durationMinutes: Int
    var schedule: Schedule?

    init(
        id: UUID = UUID(),
        name: String,
        appIDs: [String],
        mode: FocusSessionMode,
        durationMinutes: Int,
        schedule: Schedule? = nil
    ) {
        self.id = id
        self.name = name
        self.appIDs = appIDs
        self.mode = mode
        self.durationMinutes = durationMinutes
        self.schedule = schedule
    }
}

extension SessionTemplate.Schedule.Frequency {
    var displayName: String {
        switch self {
        case .once: return "One Time"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

final class SessionTemplateStore: ObservableObject {
    @Published private(set) var templates: [SessionTemplate] = []

    private let storageKey = "dialedIn.sessionTemplates"
    private let defaults = UserDefaults.standard
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let cloudSyncManager: CloudSyncManager?
    private let syncEnabledKey = "dialedIn.syncAcrossDevices"

    init(cloudSyncManager: CloudSyncManager? = .shared) {
        self.cloudSyncManager = cloudSyncManager
        encoder.outputFormatting = [.prettyPrinted]
        load()

        if defaults.bool(forKey: syncEnabledKey),
           let data = cloudSyncManager?.cloudSessionTemplatesData() {
            applyRemoteTemplates(data)
        }

        cloudSyncManager?.synchronize()
        registerForCloudUpdates()
    }

    func add(_ template: SessionTemplate) {
        templates.append(template)
        sortTemplates()
        save()
        pushToCloudIfNeeded()
    }

    func update(_ template: SessionTemplate) {
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else { return }
        templates[index] = template
        sortTemplates()
        save()
        pushToCloudIfNeeded()
    }

    func remove(_ template: SessionTemplate) {
        templates.removeAll { $0.id == template.id }
        sortTemplates()
        save()
        pushToCloudIfNeeded()
    }

    func template(withID id: UUID) -> SessionTemplate? {
        templates.first { $0.id == id }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            templates = []
            return
        }

        do {
            templates = try decoder.decode([SessionTemplate].self, from: data)
        } catch {
            templates = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(templates)
            defaults.set(data, forKey: storageKey)
        } catch {
            // Ignore errors; user can retry saving via editing.
        }
    }

    private func pushToCloudIfNeeded() {
        guard defaults.bool(forKey: syncEnabledKey),
              let cloudSyncManager else { return }
        do {
            let data = try encoder.encode(templates)
            cloudSyncManager.setSessionTemplatesData(data)
        } catch {
            // Ignore serialization errors.
        }
    }

    private func applyRemoteTemplates(_ data: Data) {
        do {
            let remoteTemplates = try decoder.decode([SessionTemplate].self, from: data)
            templates = merge(local: templates, remote: remoteTemplates)
            sortTemplates()
            save()
        } catch {
            // Ignore malformed data
        }
    }

    private func merge(local: [SessionTemplate], remote: [SessionTemplate]) -> [SessionTemplate] {
        var map: [UUID: SessionTemplate] = [:]
        for template in local {
            map[template.id] = template
        }
        for template in remote {
            map[template.id] = template
        }
        return map.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func registerForCloudUpdates() {
        cloudSyncManager?.sessionTemplatesDidChange = { [weak self] data in
            guard let self else { return }
            guard self.defaults.bool(forKey: self.syncEnabledKey) else { return }
            self.applyRemoteTemplates(data)
        }
    }

    private func sortTemplates() {
        templates.sort { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
