import Foundation

enum ResolvedIntegrationMode: Equatable {
    case navidromeReadOnly
    case disconnected

    var badgeText: String {
        switch self {
        case .navidromeReadOnly: return "Navidrome"
        case .disconnected: return "Disconnected"
        }
    }
}
