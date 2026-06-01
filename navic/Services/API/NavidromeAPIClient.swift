import Foundation
import AppKit
import CryptoKit

/// Subsonic-compatible API client for Navidrome.
/// Uses token + salt auth (md5(password + salt)) and JSON response format.
final class NavidromeAPIClient: ArtworkProvider {

    private let credentials: NavidromeCredentials
    private let session: URLSession
    private let clientName = "navic"
    private let apiVersion = "1.16.1"
    private let artworkCache = NSCache<NSString, NSImage>()

    init(credentials: NavidromeCredentials, session: URLSession? = nil) {
        self.credentials = credentials
        self.session = session ?? Self.makeSession(ignoreSSLErrors: credentials.ignoreSSLErrors)
        artworkCache.countLimit = 64
    }

    // MARK: - Public API

    func ping() async throws -> Bool {
        let response: PingResponse = try await request(endpoint: "ping", as: PingResponse.self)
        return response.status == "ok"
    }

    func nowPlaying() async throws -> [NowPlayingEntry] {
        let envelope = try await rawRequest(endpoint: "getNowPlaying", as: NowPlayingEnvelope.self)
        if envelope.subsonicResponse.status != "ok" {
            throw IntegrationError.serverError(envelope.subsonicResponse.error?.message ?? "unknown")
        }
        return envelope.subsonicResponse.nowPlaying?.entry ?? []
    }

    func song(id: String) async throws -> Track? {
        let envelope = try await rawRequest(
            endpoint: "getSong",
            queryItems: [URLQueryItem(name: "id", value: id)],
            as: SongEnvelope.self
        )
        if envelope.subsonicResponse.status != "ok" {
            throw IntegrationError.serverError(envelope.subsonicResponse.error?.message ?? "unknown")
        }
        return envelope.subsonicResponse.song.map(Track.init(from:))
    }

    func playQueueTracks() async throws -> [Track] {
        try await playQueue()?.entry?.map(Track.init(from:)) ?? []
    }

    func playQueue() async throws -> PlayQueueContainer? {
        let envelope = try await rawRequest(endpoint: "getPlayQueue", as: PlayQueueEnvelope.self)
        if envelope.subsonicResponse.status != "ok" {
            throw IntegrationError.serverError(envelope.subsonicResponse.error?.message ?? "unknown")
        }
        return envelope.subsonicResponse.playQueue
    }

    func star(id: String) async throws {
        try await void(endpoint: "star", queryItems: [URLQueryItem(name: "id", value: id)])
    }

    func unstar(id: String) async throws {
        try await void(endpoint: "unstar", queryItems: [URLQueryItem(name: "id", value: id)])
    }

    func artwork(for track: Track, size: Int = 512) async throws -> NSImage? {
        guard let coverArtId = track.coverArtId ?? Optional(track.id) else { return nil }
        let cacheKey = "\(coverArtId)@\(size)" as NSString
        if let cached = artworkCache.object(forKey: cacheKey) { return cached }

        let url = try buildURL(
            endpoint: "getCoverArt",
            queryItems: [
                URLQueryItem(name: "id", value: coverArtId),
                URLQueryItem(name: "size", value: String(size))
            ]
        )
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let image = NSImage(data: data) else { return nil }
        artworkCache.setObject(image, forKey: cacheKey)
        return image
    }

    // MARK: - URL construction

    private func buildURL(endpoint: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(
            url: credentials.serverURL.appendingPathComponent("rest").appendingPathComponent("\(endpoint).view"),
            resolvingAgainstBaseURL: false
        ) else { throw IntegrationError.invalidResponse("URL building failed") }

        let salt = randomSalt()
        let token = md5Hex(credentials.password + salt)

        var items: [URLQueryItem] = [
            URLQueryItem(name: "u", value: credentials.username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: apiVersion),
            URLQueryItem(name: "c", value: clientName),
            URLQueryItem(name: "f", value: "json"),
        ]
        items.append(contentsOf: queryItems)
        components.queryItems = items

        guard let url = components.url else {
            throw IntegrationError.invalidResponse("URL components empty")
        }
        return url
    }

    // MARK: - Requests

    private func request<T: Decodable>(endpoint: String, queryItems: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        let url = try buildURL(endpoint: endpoint, queryItems: queryItems)
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw IntegrationError.invalidResponse("Non-HTTP response")
            }
            guard 200..<300 ~= http.statusCode else {
                throw IntegrationError.serverError("HTTP \(http.statusCode)")
            }
            do {
                let envelope = try JSONDecoder().decode(GenericEnvelope<T>.self, from: data)
                return envelope.subsonicResponse
            } catch {
                throw IntegrationError.invalidResponse("decode: \(error.localizedDescription)")
            }
        } catch let error as IntegrationError {
            throw error
        } catch {
            throw IntegrationError.networkError(error)
        }
    }

    private func rawRequest<T: Decodable>(endpoint: String, queryItems: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        let url = try buildURL(endpoint: endpoint, queryItems: queryItems)
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw IntegrationError.serverError("HTTP error")
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw IntegrationError.invalidResponse("decode: \(error.localizedDescription)")
            }
        } catch let error as IntegrationError {
            throw error
        } catch {
            throw IntegrationError.networkError(error)
        }
    }

    private func void(endpoint: String, queryItems: [URLQueryItem]) async throws {
        _ = try await request(endpoint: endpoint, queryItems: queryItems, as: StarResponse.self)
    }

    // MARK: - Helpers

    private func randomSalt(length: Int = 16) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    private func md5Hex(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func makeSession(ignoreSSLErrors: Bool) -> URLSession {
        guard ignoreSSLErrors else { return .shared }

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(
            configuration: configuration,
            delegate: InsecureSSLDelegate(),
            delegateQueue: nil
        )
    }
}

private final class InsecureSSLDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }
}

// MARK: - Envelopes

private struct GenericEnvelope<T: Decodable>: Decodable {
    let subsonicResponse: T
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

private struct NowPlayingEnvelope: Decodable {
    let subsonicResponse: NowPlayingResponse
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

private struct SongEnvelope: Decodable {
    let subsonicResponse: SongResponse
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

private struct PlayQueueEnvelope: Decodable {
    let subsonicResponse: PlayQueueResponse
    enum CodingKeys: String, CodingKey { case subsonicResponse = "subsonic-response" }
}

// MARK: - Track adapters

extension Track {
    init(from child: SubsonicChild) {
        self.init(
            id: child.id,
            title: child.title ?? "Unknown",
            artist: child.artist ?? "Unknown",
            album: child.album,
            albumId: child.albumId,
            artistId: child.artistId,
            duration: child.duration.map(TimeInterval.init),
            coverArtId: child.coverArt,
            isFavorite: child.starred != nil,
            year: child.year,
            genre: child.genre
        )
    }

    init(from entry: NowPlayingEntry) {
        self.init(
            id: entry.id,
            title: entry.title ?? "Unknown",
            artist: entry.artist ?? "Unknown",
            album: entry.album,
            albumId: entry.albumId,
            artistId: entry.artistId,
            duration: entry.duration.map(TimeInterval.init),
            coverArtId: entry.coverArt,
            isFavorite: entry.starred != nil,
            year: entry.year,
            genre: entry.genre
        )
    }
}
