import Foundation

struct Track: Equatable, Identifiable, Hashable {
    let id: String
    var title: String
    var artist: String
    var album: String?
    var albumId: String?
    var artistId: String?
    var duration: TimeInterval?
    var coverArtId: String?
    var isFavorite: Bool
    var year: Int?
    var genre: String?

    init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        albumId: String? = nil,
        artistId: String? = nil,
        duration: TimeInterval? = nil,
        coverArtId: String? = nil,
        isFavorite: Bool = false,
        year: Int? = nil,
        genre: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.albumId = albumId
        self.artistId = artistId
        self.duration = duration
        self.coverArtId = coverArtId
        self.isFavorite = isFavorite
        self.year = year
        self.genre = genre
    }
}

extension Track {
    static let placeholder = Track(
        id: "placeholder",
        title: "Nothing playing",
        artist: "—",
        album: nil,
        duration: nil
    )
}
