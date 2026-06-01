import Foundation
import Testing
@testable import navic

struct SubsonicMappingTests {
    @Test func nowPlayingResponseDecodesAndMapsToTrack() throws {
        let data = Data(
            """
            {
              "subsonic-response": {
                "status": "ok",
                "nowPlaying": {
                  "entry": [
                    {
                      "username": "max",
                      "minutesAgo": 2,
                      "id": "song-1",
                      "title": "A Title",
                      "artist": "An Artist",
                      "album": "An Album",
                      "albumId": "album-1",
                      "artistId": "artist-1",
                      "duration": 245,
                      "coverArt": "cover-1",
                      "starred": "2026-05-31T12:00:00Z",
                      "year": 2026,
                      "genre": "Electronic"
                    }
                  ]
                }
              }
            }
            """.utf8
        )

        let envelope = try JSONDecoder().decode(SubsonicEnvelope<NowPlayingResponse>.self, from: data)
        let entry = try #require(envelope.subsonicResponse.nowPlaying?.entry?.first)
        let track = Track(from: entry)

        #expect(envelope.subsonicResponse.status == "ok")
        #expect(track.id == "song-1")
        #expect(track.title == "A Title")
        #expect(track.artist == "An Artist")
        #expect(track.album == "An Album")
        #expect(track.albumId == "album-1")
        #expect(track.artistId == "artist-1")
        #expect(track.duration == 245)
        #expect(track.coverArtId == "cover-1")
        #expect(track.isFavorite)
        #expect(track.year == 2026)
        #expect(track.genre == "Electronic")
    }

    @Test func subsonicChildMappingUsesUnknownFallbacksAndFavoriteState() {
        let child = SubsonicChild(
            id: "song-2",
            parent: nil,
            title: nil,
            artist: nil,
            album: nil,
            albumId: nil,
            artistId: nil,
            duration: nil,
            coverArt: nil,
            year: nil,
            genre: nil,
            starred: nil,
            path: nil
        )

        let track = Track(from: child)

        #expect(track.id == "song-2")
        #expect(track.title == "Unknown")
        #expect(track.artist == "Unknown")
        #expect(track.duration == nil)
        #expect(track.coverArtId == nil)
        #expect(!track.isFavorite)
    }

    @Test func playQueueResponseDecodesCurrentAndPosition() throws {
        let data = Data(
            """
            {
              "subsonic-response": {
                "status": "ok",
                "playQueue": {
                  "current": "song-2",
                  "position": 42000,
                  "username": "max",
                  "entry": [
                    { "id": "song-1", "title": "First", "artist": "Artist" },
                    { "id": "song-2", "title": "Second", "artist": "Artist", "duration": 180 }
                  ]
                }
              }
            }
            """.utf8
        )

        let envelope = try JSONDecoder().decode(SubsonicEnvelope<PlayQueueResponse>.self, from: data)
        let queue = try #require(envelope.subsonicResponse.playQueue)

        #expect(queue.current == "song-2")
        #expect(queue.position == 42_000)
        #expect(queue.entry?.map(\.id) == ["song-1", "song-2"])
    }
}
