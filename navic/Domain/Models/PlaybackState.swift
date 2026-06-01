import Foundation

enum PlaybackStatus: Equatable {
    case stopped
    case playing
    case paused
    case unknown
}

struct PlaybackState: Equatable {
    var status: PlaybackStatus
    var elapsed: TimeInterval
    var duration: TimeInterval?
    var volume: Float?
    var isMuted: Bool
    var updatedAt: Date

    init(
        status: PlaybackStatus = .unknown,
        elapsed: TimeInterval = 0,
        duration: TimeInterval? = nil,
        volume: Float? = nil,
        isMuted: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.status = status
        self.elapsed = elapsed
        self.duration = duration
        self.volume = volume
        self.isMuted = isMuted
        self.updatedAt = updatedAt
    }

    static let empty = PlaybackState()

    var progress: Double {
        guard let duration, duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }
}
