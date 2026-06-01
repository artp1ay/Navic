import Foundation

protocol NowPlayingProvider: AnyObject {
    func snapshot() async throws -> (track: Track?, state: PlaybackState)
}
