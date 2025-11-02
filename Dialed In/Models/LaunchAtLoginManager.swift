import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    static func synchronizeStoredPreference(key: String = "dialedIn.launchAtLogin") {
        let currentStatus = isEnabled
        let storedValue = UserDefaults.standard.bool(forKey: key)

        guard currentStatus != storedValue else { return }
        UserDefaults.standard.set(currentStatus, forKey: key)
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            throw LaunchPreferenceError.unsupportedPlatform
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            throw LaunchPreferenceError.registrationFailed(error)
        }
    }

    enum LaunchPreferenceError: LocalizedError {
        case unsupportedPlatform
        case registrationFailed(Error)

        var errorDescription: String? {
            switch self {
            case .unsupportedPlatform:
                return "Launch at login requires macOS 13 or later."
            case .registrationFailed(let error):
                return error.localizedDescription
            }
        }
    }
}
