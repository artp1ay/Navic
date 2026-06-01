import Foundation
import AppKit

/// Builds the active provider stack based on user settings + live system-media state.
@MainActor
struct ProviderFactory {

    struct Stack {
        let mode: ResolvedIntegrationMode
        let nowPlaying: NowPlayingProvider?
        let artwork: ArtworkProvider?
        let apiClient: NavidromeAPIClient?
    }

    let settings: AppSettings

    func build() -> Stack {
        let credentials = settings.credentials
        let apiClient = credentials.map { NavidromeAPIClient(credentials: $0) }

        let navidromeNowPlaying: NowPlayingProvider? = {
            guard let apiClient, let username = credentials?.username else { return nil }
            return NavidromeNowPlayingProvider(client: apiClient, username: username)
        }()

        let mode: ResolvedIntegrationMode = apiClient == nil ? .disconnected : .navidromeReadOnly

        return Stack(
            mode: mode,
            nowPlaying: navidromeNowPlaying,
            artwork: apiClient,
            apiClient: apiClient
        )
    }
}
