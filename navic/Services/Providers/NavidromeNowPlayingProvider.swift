import Foundation

/// Reads the most recent track played by the configured user from Navidrome's `getNowPlaying` endpoint.
/// Note: Navidrome does not currently expose precise elapsed/position information through Subsonic API,
/// so playback elapsed time is best-effort (based on `minutesAgo`).
final class NavidromeNowPlayingProvider: NowPlayingProvider {

    private let client: NavidromeAPIClient
    private let username: String
    private var lastQueueTrackId: String?
    private var lastQueuePosition: Int?

    init(client: NavidromeAPIClient, username: String) {
        self.client = client
        self.username = username
    }

    func snapshot() async throws -> (track: Track?, state: PlaybackState) {
        let entries = try await client.nowPlaying()
        if let entry = bestEntry(in: entries) {
            lastQueueTrackId = nil
            lastQueuePosition = nil
            return (Track(from: entry), state(for: entry))
        }

        guard let queue = try await client.playQueue(),
              let child = currentQueueEntry(in: queue)
        else {
            lastQueueTrackId = nil
            lastQueuePosition = nil
            return (nil, PlaybackState(status: .stopped))
        }

        return (Track(from: child), state(for: child, queue: queue))
    }

    private func bestEntry(in entries: [NowPlayingEntry]) -> NowPlayingEntry? {
        entries
            .filter({ $0.username?.caseInsensitiveCompare(username) == .orderedSame })
            .min(by: { ($0.minutesAgo ?? Int.max) < ($1.minutesAgo ?? Int.max) })
            ?? entries.min(by: { ($0.minutesAgo ?? Int.max) < ($1.minutesAgo ?? Int.max) })
    }

    private func state(for entry: NowPlayingEntry?) -> PlaybackState {
        guard let entry else { return PlaybackState(status: .stopped) }

        return PlaybackState(
            status: .playing,
            elapsed: TimeInterval(entry.minutesAgo ?? 0) * 60,
            duration: entry.duration.map(TimeInterval.init)
        )
    }

    private func currentQueueEntry(in queue: PlayQueueContainer) -> SubsonicChild? {
        guard let entries = queue.entry, !entries.isEmpty else { return nil }
        if let current = queue.current,
           let match = entries.first(where: { $0.id == current }) {
            return match
        }
        return entries.first
    }

    private func state(for child: SubsonicChild, queue: PlayQueueContainer) -> PlaybackState {
        defer {
            lastQueueTrackId = child.id
            lastQueuePosition = queue.position
        }

        guard let position = queue.position else {
            return PlaybackState(status: .playing, duration: child.duration.map(TimeInterval.init))
        }

        let didAdvance = lastQueueTrackId != child.id || lastQueuePosition.map { position > $0 } ?? true
        return PlaybackState(
            status: didAdvance ? .playing : .paused,
            elapsed: TimeInterval(position) / 1000,
            duration: child.duration.map(TimeInterval.init)
        )
    }
}
