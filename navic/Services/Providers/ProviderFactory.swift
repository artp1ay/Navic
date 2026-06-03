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
        let autoProvider: AutoSourceProvider?
    }

    let settings: AppSettings
    /// Override hook so unit tests can stub the Apple Music bridge without
    /// touching real Music.app via Apple Events.
    var appleMusicScriptingProvider: () -> AppleMusicScripting = { AppleMusicScriptingBridge() }

    func build() -> Stack {
        switch settings.integrationSource {
        case .navidrome: return buildNavidromeStack()
        case .appleMusic: return buildAppleMusicStack()
        case .auto: return buildAutoStack()
        }
    }

    private func buildNavidromeStack() -> Stack {
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
            apiClient: apiClient,
            autoProvider: nil
        )
    }

    private func buildAppleMusicStack() -> Stack {
        let scripting = appleMusicScriptingProvider()
        guard scripting.isMusicAppAvailable else {
            return Stack(mode: .disconnected, nowPlaying: nil, artwork: nil, apiClient: nil, autoProvider: nil)
        }
        let provider = AppleMusicNowPlayingProvider(scripting: scripting)
        return Stack(
            mode: .appleMusic,
            nowPlaying: provider,
            artwork: provider,
            apiClient: nil,
            autoProvider: nil
        )
    }

    private func buildAutoStack() -> Stack {
        let scripting = appleMusicScriptingProvider()
        let appleMusic: AppleMusicNowPlayingProvider? = scripting.isMusicAppAvailable
            ? AppleMusicNowPlayingProvider(scripting: scripting)
            : nil

        let credentials = settings.credentials
        let apiClient = credentials.map { NavidromeAPIClient(credentials: $0) }
        let navidromeNowPlaying: NowPlayingProvider? = {
            guard let apiClient, let username = credentials?.username else { return nil }
            return NavidromeNowPlayingProvider(client: apiClient, username: username)
        }()

        guard appleMusic != nil || navidromeNowPlaying != nil else {
            return Stack(mode: .disconnected, nowPlaying: nil, artwork: nil, apiClient: nil, autoProvider: nil)
        }

        let auto = AutoSourceProvider(
            appleMusic: appleMusic,
            navidromeNowPlaying: navidromeNowPlaying,
            navidromeArtwork: apiClient
        )

        // Initial mode — preferred ordering is Apple Music → Navidrome. The
        // coordinator will refine the resolved mode after the first snapshot.
        let initialMode: ResolvedIntegrationMode = appleMusic != nil ? .appleMusic : .navidromeReadOnly

        return Stack(
            mode: initialMode,
            nowPlaying: auto,
            artwork: auto,
            apiClient: apiClient,
            autoProvider: auto
        )
    }
}
