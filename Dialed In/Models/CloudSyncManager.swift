import Foundation
import Combine

final class CloudSyncManager {
    static let shared = CloudSyncManager()

    enum Key: String {
        case selectedAppIDs = "cloud.selectedAppIDs"
        case sessionHistory = "cloud.sessionHistory"
        case hotKeyConfiguration = "cloud.hotKeyConfiguration"
        case sessionTemplates = "cloud.sessionTemplates"
    }

    struct HotKeyPayload: Codable, Equatable {
        var keyCode: UInt32
        var modifiers: UInt
    }

    private let store = NSUbiquitousKeyValueStore.default
    private var observers: Set<AnyCancellable> = []

    var selectedAppIDsDidChange: (([String]) -> Void)?
    var sessionHistoryDidChange: (([SessionRecord]) -> Void)?
    var hotKeyConfigurationDidChange: ((HotKeyPayload) -> Void)?
    var sessionTemplatesDidChange: ((Data) -> Void)?

    private init() {
        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .sink { [weak self] notification in
                guard let self,
                      let userInfo = notification.userInfo,
                      let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
                    return
                }

                handleChangedKeys(keys)
            }
            .store(in: &observers)

        store.synchronize()
    }

    func synchronize() {
        store.synchronize()
    }

    func setSelectedAppIDs(_ ids: [String], enabled: Bool) {
        guard enabled else { return }
        store.set(ids, forKey: Key.selectedAppIDs.rawValue)
        store.synchronize()
    }

    func cloudSelectedAppIDs() -> [String]? {
        store.array(forKey: Key.selectedAppIDs.rawValue) as? [String]
    }

    func setSessionHistory(_ records: [SessionRecord], enabled: Bool) {
        guard enabled else { return }

        do {
            let data = try JSONEncoder().encode(records)
            store.set(data, forKey: Key.sessionHistory.rawValue)
            store.synchronize()
        } catch {
            // Ignore errors; local storage still holds the data.
        }
    }

    func cloudSessionHistory() -> [SessionRecord]? {
        guard let data = store.data(forKey: Key.sessionHistory.rawValue) else {
            return nil
        }

        return try? JSONDecoder().decode([SessionRecord].self, from: data)
    }

    func setHotKeyConfiguration(_ payload: HotKeyPayload, enabled: Bool) {
        guard enabled else { return }
        do {
            let data = try JSONEncoder().encode(payload)
            store.set(data, forKey: Key.hotKeyConfiguration.rawValue)
            store.synchronize()
        } catch {
            // Ignore serialization errors; local config stays authoritative.
        }
    }

    func cloudHotKeyConfiguration() -> HotKeyPayload? {
        guard let data = store.data(forKey: Key.hotKeyConfiguration.rawValue) else {
            return nil
        }
        return try? JSONDecoder().decode(HotKeyPayload.self, from: data)
    }

    func setSessionTemplatesData(_ data: Data) {
        store.set(data, forKey: Key.sessionTemplates.rawValue)
        store.synchronize()
    }

    func cloudSessionTemplatesData() -> Data? {
        store.data(forKey: Key.sessionTemplates.rawValue)
    }

    private func handleChangedKeys(_ keys: [String]) {
        for key in keys {
            switch key {
            case Key.selectedAppIDs.rawValue:
                let ids = cloudSelectedAppIDs() ?? []
                selectedAppIDsDidChange?(ids)
                NotificationCenter.default.post(
                    name: .cloudSelectedAppIDsDidChange,
                    object: nil,
                    userInfo: ["ids": ids]
                )
            case Key.sessionHistory.rawValue:
                let records = cloudSessionHistory() ?? []
                sessionHistoryDidChange?(records)
            case Key.hotKeyConfiguration.rawValue:
                if let payload = cloudHotKeyConfiguration() {
                    hotKeyConfigurationDidChange?(payload)
                }
            case Key.sessionTemplates.rawValue:
                if let data = cloudSessionTemplatesData() {
                    sessionTemplatesDidChange?(data)
                }
            default:
                break
            }
        }
    }
}

extension Notification.Name {
    static let cloudSelectedAppIDsDidChange = Notification.Name("CloudSyncSelectedAppIDsDidChange")
}
