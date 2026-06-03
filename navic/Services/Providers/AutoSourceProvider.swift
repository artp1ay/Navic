import Foundation
import AppKit

/// Composite that mirrors whichever configured source is currently producing
/// playback. Apple Music wins when Music.app reports a current track, since
/// it's local and authoritative; Navidrome takes over when Music is idle.
/// The active source is exposed for `PlayerCoordinator` to surface in the
/// resolved mode badge.
final class AutoSourceProvider: NowPlayingProvider, ArtworkProvider {

    private let appleMusic: AppleMusicNowPlayingProvider?
    private let navidromeNowPlaying: NowPlayingProvider?
    private let navidromeArtwork: ArtworkProvider?

    /// Updated after each `snapshot()` to reflect which underlying provider
    /// returned the most recent track. Defaults to `.disconnected` until the
    /// first successful read.
    private(set) var activeMode: ResolvedIntegrationMode = .disconnected

    init(
        appleMusic: AppleMusicNowPlayingProvider?,
        navidromeNowPlaying: NowPlayingProvider?,
        navidromeArtwork: ArtworkProvider?
    ) {
        self.appleMusic = appleMusic
        self.navidromeNowPlaying = navidromeNowPlaying
        self.navidromeArtwork = navidromeArtwork
    }

    func snapshot() async throws -> (track: Track?, state: PlaybackState) {
        if let appleMusic {
            if let result = try? await appleMusic.snapshot(), result.track != nil {
                activeMode = .appleMusic
                return result
            }
        }
        if let navidromeNowPlaying {
            do {
                let result = try await navidromeNowPlaying.snapshot()
                if result.track != nil {
                    activeMode = .navidromeReadOnly
                    return result
                }
            } catch {
                activeMode = .disconnected
                throw error
            }
        }
        // Neither source has anything to play right now. If Apple Music is the
        // only configured source, keep the badge accurate; otherwise Navidrome
        // is the only configured fallback.
        activeMode = appleMusic != nil ? .appleMusic : (navidromeNowPlaying != nil ? .navidromeReadOnly : .disconnected)
        return (nil, PlaybackState(status: .stopped))
    }

    func artwork(for track: Track, size: Int) async throws -> NSImage? {
        switch activeMode {
        case .appleMusic: return try await appleMusic?.artwork(for: track, size: size)
        case .navidromeReadOnly: return try await navidromeArtwork?.artwork(for: track, size: size)
        case .disconnected: return nil
        }
    }
}
