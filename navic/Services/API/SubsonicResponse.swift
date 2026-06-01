import Foundation

struct SubsonicEnvelope<T: Decodable>: Decodable {
    let subsonicResponse: T

    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

struct SubsonicError: Decodable {
    let code: Int
    let message: String?
}

struct SubsonicStatus: Decodable {
    let status: String
    let version: String?
    let type: String?
    let serverVersion: String?
    let error: SubsonicError?
}

struct SubsonicChild: Decodable {
    let id: String
    let parent: String?
    let title: String?
    let artist: String?
    let album: String?
    let albumId: String?
    let artistId: String?
    let duration: Int?
    let coverArt: String?
    let year: Int?
    let genre: String?
    let starred: String?
    let path: String?
}

struct NowPlayingEntry: Decodable {
    let username: String?
    let minutesAgo: Int?
    let playerId: Int?
    let playerName: String?
    let id: String
    let title: String?
    let artist: String?
    let album: String?
    let albumId: String?
    let artistId: String?
    let duration: Int?
    let coverArt: String?
    let starred: String?
    let year: Int?
    let genre: String?
}

struct NowPlayingContainer: Decodable {
    let entry: [NowPlayingEntry]?
}

struct NowPlayingResponse: Decodable {
    let status: String
    let nowPlaying: NowPlayingContainer?
    let error: SubsonicError?
}

struct SongResponse: Decodable {
    let status: String
    let song: SubsonicChild?
    let error: SubsonicError?
}

struct PlayQueueContainer: Decodable {
    let entry: [SubsonicChild]?
    let current: String?
    let position: Int?
    let username: String?
    let changed: String?
}

struct PlayQueueResponse: Decodable {
    let status: String
    let playQueue: PlayQueueContainer?
    let error: SubsonicError?
}

struct PingResponse: Decodable {
    let status: String
    let version: String?
    let type: String?
    let serverVersion: String?
    let error: SubsonicError?
}

struct StarResponse: Decodable {
    let status: String
    let error: SubsonicError?
}
