import Foundation
import Testing
@testable import navic

@MainActor
struct AutoSourceProviderTests {
    @Test func picksAppleMusicWhenItHasATrack() async throws {
        let appleMusic = AppleMusicNowPlayingProvider(scripting: StubAppleMusicScripting(
            snapshot: makeSnapshot(persistentId: "AM-1", title: "Music Track")
        ))
        let navidrome = StubNowPlayingProvider(track: Track(id: "ND-1", title: "Server Track", artist: "Artist"))
        let provider = AutoSourceProvider(
            appleMusic: appleMusic,
            navidromeNowPlaying: navidrome,
            navidromeArtwork: nil
        )

        let result = try await provider.snapshot()

        #expect(result.track?.id == "AM-1")
        #expect(provider.activeMode == .appleMusic)
    }

    @Test func fallsBackToNavidromeWhenAppleMusicHasNoTrack() async throws {
        let appleMusic = AppleMusicNowPlayingProvider(scripting: StubAppleMusicScripting())
        let navidrome = StubNowPlayingProvider(track: Track(id: "ND-2", title: "Fallback", artist: "Artist"))
        let provider = AutoSourceProvider(
            appleMusic: appleMusic,
            navidromeNowPlaying: navidrome,
            navidromeArtwork: nil
        )

        let result = try await provider.snapshot()

        #expect(result.track?.id == "ND-2")
        #expect(provider.activeMode == .navidromeReadOnly)
    }

    @Test func reportsStoppedWhenNeitherSourceHasATrack() async throws {
        let appleMusic = AppleMusicNowPlayingProvider(scripting: StubAppleMusicScripting())
        let navidrome = StubNowPlayingProvider(track: nil)
        let provider = AutoSourceProvider(
            appleMusic: appleMusic,
            navidromeNowPlaying: navidrome,
            navidromeArtwork: nil
        )

        let result = try await provider.snapshot()

        #expect(result.track == nil)
        #expect(result.state.status == .stopped)
    }

    @Test func appleMusicErrorIsSwallowedSoNavidromeCanTakeOver() async throws {
        let appleMusic = AppleMusicNowPlayingProvider(scripting: ThrowingAppleMusicScripting())
        let navidrome = StubNowPlayingProvider(track: Track(id: "ND-3", title: "T", artist: "A"))
        let provider = AutoSourceProvider(
            appleMusic: appleMusic,
            navidromeNowPlaying: navidrome,
            navidromeArtwork: nil
        )

        let result = try await provider.snapshot()

        #expect(result.track?.id == "ND-3")
        #expect(provider.activeMode == .navidromeReadOnly)
    }

    private func makeSnapshot(persistentId: String, title: String) -> AppleMusicSnapshot {
        AppleMusicSnapshot(
            playerState: .playing,
            persistentId: persistentId,
            title: title,
            artist: "Artist",
            album: "Album",
            duration: 180,
            position: 30
        )
    }
}

private final class StubNowPlayingProvider: NowPlayingProvider {
    let track: Track?

    init(track: Track?) {
        self.track = track
    }

    func snapshot() async throws -> (track: Track?, state: PlaybackState) {
        let status: PlaybackStatus = track == nil ? .stopped : .playing
        return (track, PlaybackState(status: status, elapsed: 10, duration: 120))
    }
}

private final class ThrowingAppleMusicScripting: AppleMusicScripting {
    var isMusicAppAvailable: Bool { true }
    func snapshot() async throws -> AppleMusicSnapshot? {
        throw AppleMusicScriptingError.notAuthorized
    }
    func artworkData() async throws -> Data? { nil }
}
