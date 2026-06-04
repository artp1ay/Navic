import Foundation
import AppKit

/// Reads now-playing state and artwork from the local Music.app via the
/// Apple Events scripting interface. Unlike the Navidrome path, playback
/// position and duration are exposed precisely by Music, so progress is
/// directly proportional.
final class AppleMusicNowPlayingProvider: NowPlayingProvider, ArtworkProvider {

    private let scripting: AppleMusicScripting
    private let artworkCache = NSCache<NSString, NSImage>()
    private var pendingTrackId: String?
    private var pendingAttempts: Int = 0

    /// Roughly two seconds at the 0.25s poll cadence — long enough for Music to
    /// finish pulling cloud artwork after a track change, short enough to stop
    /// hammering AppleScript when the track genuinely has no cover.
    private static let maxArtworkAttempts = 8

    init(scripting: AppleMusicScripting) {
        self.scripting = scripting
        artworkCache.countLimit = 32
    }

    func snapshot() async throws -> (track: Track?, state: PlaybackState) {
        guard let snapshot = try await scripting.snapshot() else {
            pendingTrackId = nil
            pendingAttempts = 0
            return (nil, PlaybackState(status: .stopped))
        }
        let track = Track(from: snapshot)
        await prefetchArtworkIfNeeded(for: track)
        return (track, PlaybackState(from: snapshot))
    }

    func artwork(for track: Track, size: Int) async throws -> NSImage? {
        artworkCache.object(forKey: track.id as NSString)
    }

    /// Music only exposes `data of artwork 1` for the track that's playing
    /// *right now*. If we wait for `artwork(for:size:)` to run, the polling
    /// loop or an auto-advance can move Music onto the next track first,
    /// the data query fails, and the widget renders without a cover. Fetching
    /// here — back-to-back with `scripting.snapshot()` on the same serial
    /// queue — keeps the read tied to the track we just observed.
    ///
    /// A single failed fetch is common (Music still streaming the cover from
    /// the cloud, or a transient race during a track change), so we retry on
    /// subsequent polls until either we get the data or we've burned the
    /// per-track attempt budget.
    private func prefetchArtworkIfNeeded(for track: Track) async {
        let key = track.id as NSString
        if artworkCache.object(forKey: key) != nil { return }

        if pendingTrackId != track.id {
            pendingTrackId = track.id
            pendingAttempts = 0
        }
        guard pendingAttempts < Self.maxArtworkAttempts else { return }
        pendingAttempts += 1

        guard let data = try? await scripting.artworkData(),
              let image = NSImage(data: data) else { return }
        artworkCache.setObject(image, forKey: key)
    }
}

extension Track {
    init(from snapshot: AppleMusicSnapshot) {
        self.init(
            id: snapshot.persistentId,
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            duration: snapshot.duration
        )
    }
}

extension PlaybackState {
    init(from snapshot: AppleMusicSnapshot) {
        let status: PlaybackStatus
        switch snapshot.playerState {
        case .playing, .fastForwarding, .rewinding: status = .playing
        case .paused: status = .paused
        case .stopped: status = .stopped
        case .unknown: status = .unknown
        }
        self.init(
            status: status,
            elapsed: snapshot.position ?? 0,
            duration: snapshot.duration
        )
    }
}
