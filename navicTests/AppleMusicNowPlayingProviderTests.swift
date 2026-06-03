import Foundation
import Testing
@testable import navic

struct AppleMusicNowPlayingProviderTests {
    @Test func reportsStoppedWhenScriptingReturnsNoSnapshot() async throws {
        let scripting = StubAppleMusicScripting()
        let provider = AppleMusicNowPlayingProvider(scripting: scripting)

        let result = try await provider.snapshot()

        #expect(result.track == nil)
        #expect(result.state.status == .stopped)
    }

    @Test func mapsPlayingSnapshotToPlayingTrackWithPosition() async throws {
        let scripting = StubAppleMusicScripting(
            snapshot: AppleMusicSnapshot(
                playerState: .playing,
                persistentId: "PID-1",
                title: "Title",
                artist: "Artist",
                album: "Album",
                duration: 200,
                position: 50
            )
        )
        let provider = AppleMusicNowPlayingProvider(scripting: scripting)

        let result = try await provider.snapshot()

        let track = try #require(result.track)
        #expect(track.id == "PID-1")
        #expect(track.title == "Title")
        #expect(track.artist == "Artist")
        #expect(track.album == "Album")
        #expect(track.duration == 200)
        #expect(result.state.status == .playing)
        #expect(result.state.elapsed == 50)
        #expect(result.state.duration == 200)
    }

    @Test func pausedAndStoppedStatesAreMappedFaithfully() async throws {
        let pausedProvider = AppleMusicNowPlayingProvider(scripting: StubAppleMusicScripting(
            snapshot: makeSnapshot(state: .paused)
        ))
        let stoppedProvider = AppleMusicNowPlayingProvider(scripting: StubAppleMusicScripting(
            snapshot: makeSnapshot(state: .stopped)
        ))

        let paused = try await pausedProvider.snapshot()
        let stopped = try await stoppedProvider.snapshot()

        #expect(paused.state.status == .paused)
        #expect(stopped.state.status == .stopped)
    }

    @Test func snapshotPrefetchesArtworkSoArtworkLookupHitsCache() async throws {
        let scripting = StubAppleMusicScripting(
            snapshot: makeSnapshot(state: .playing, persistentId: "PID-CACHED"),
            artworkData: TestImageFixture.pngData
        )
        let provider = AppleMusicNowPlayingProvider(scripting: scripting)

        _ = try await provider.snapshot()
        let image = try await provider.artwork(for: try #require(makeTrack(id: "PID-CACHED")), size: 256)

        #expect(image != nil)
        #expect(scripting.artworkRequestCount == 1)
    }

    @Test func artworkIsOnlyRefetchedWhenTrackChanges() async throws {
        let scripting = StubAppleMusicScripting(
            snapshot: makeSnapshot(state: .playing, persistentId: "PID-1"),
            artworkData: TestImageFixture.pngData
        )
        let provider = AppleMusicNowPlayingProvider(scripting: scripting)

        _ = try await provider.snapshot()
        _ = try await provider.snapshot()
        _ = try await provider.snapshot()

        #expect(scripting.artworkRequestCount == 1)
    }

    @Test func artworkLookupForOtherTrackReturnsNil() async throws {
        let scripting = StubAppleMusicScripting(
            snapshot: makeSnapshot(state: .playing, persistentId: "PID-1"),
            artworkData: TestImageFixture.pngData
        )
        let provider = AppleMusicNowPlayingProvider(scripting: scripting)
        _ = try await provider.snapshot()

        let other = try #require(makeTrack(id: "PID-OTHER"))
        let image = try await provider.artwork(for: other, size: 256)

        #expect(image == nil)
    }

    private func makeSnapshot(
        state: AppleMusicPlayerState,
        persistentId: String = "PID-1"
    ) -> AppleMusicSnapshot {
        AppleMusicSnapshot(
            playerState: state,
            persistentId: persistentId,
            title: "Title",
            artist: "Artist",
            album: "Album",
            duration: 200,
            position: 25
        )
    }

    private func makeTrack(id: String) -> Track? {
        Track(id: id, title: "T", artist: "A")
    }
}

final class StubAppleMusicScripting: AppleMusicScripting {
    var isMusicAppAvailable: Bool = true
    private(set) var artworkRequestCount = 0
    private let stubSnapshot: AppleMusicSnapshot?
    private let stubArtwork: Data?

    init(snapshot: AppleMusicSnapshot? = nil, artworkData: Data? = nil) {
        self.stubSnapshot = snapshot
        self.stubArtwork = artworkData
    }

    func snapshot() async throws -> AppleMusicSnapshot? {
        stubSnapshot
    }

    func artworkData() async throws -> Data? {
        artworkRequestCount += 1
        return stubArtwork
    }
}

enum TestImageFixture {
    /// 1×1 transparent PNG — smallest valid decodable payload.
    static let pngData: Data = Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82
    ])
}
