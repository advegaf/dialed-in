import Foundation

enum FocusSessionMode: String, CaseIterable, Identifiable, Codable {
    case allowList = "Allow List"
    case blockList = "Block List"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .allowList:
            return "Only the apps you choose remain reachable."
        case .blockList:
            return "Everything is open except the apps you block."
        }
    }

    var icon: String {
        switch self {
        case .allowList:
            return "lock.display"
        case .blockList:
            return "nosign"
        }
    }
}
