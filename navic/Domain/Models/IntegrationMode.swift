import Foundation

enum IntegrationSource: String, CaseIterable, Identifiable, Codable {
    case auto
    case navidrome
    case appleMusic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .navidrome: return "Navidrome"
        case .appleMusic: return "Apple Music"
        }
    }

    var systemImageName: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .navidrome: return "network"
        case .appleMusic: return "music.note"
        }
    }
}

enum ResolvedIntegrationMode: Equatable {
    case navidromeReadOnly
    case appleMusic
    case disconnected

    var badgeText: String {
        switch self {
        case .navidromeReadOnly: return "Navidrome"
        case .appleMusic: return "Apple Music"
        case .disconnected: return "Disconnected"
        }
    }
}
