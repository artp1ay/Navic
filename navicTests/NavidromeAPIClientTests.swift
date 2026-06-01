import CryptoKit
import Foundation
import Testing
@testable import navic

struct NavidromeAPIClientTests {
    @Test func nowPlayingBuildsAuthenticatedSubsonicRequest() async throws {
        let recorder = URLRequestRecorder(
            statusCode: 200,
            body:
                """
                {
                  "subsonic-response": {
                    "status": "ok",
                    "nowPlaying": {
                      "entry": [
                        { "username": "max", "minutesAgo": 0, "id": "song-1", "title": "Title", "artist": "Artist" }
                      ]
                    }
                  }
                }
                """
        )
        let client = NavidromeAPIClient(
            credentials: try credentials(),
            session: recorder.session
        )

        let entries = try await client.nowPlaying()
        let request = try #require(recorder.lastRequest)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        let salt = try #require(items["s"])

        #expect(entries.map(\.id) == ["song-1"])
        #expect(url.path == "/rest/getNowPlaying.view")
        #expect(items["u"] == "max")
        #expect(items["v"] == "1.16.1")
        #expect(items["c"] == "navic")
        #expect(items["f"] == "json")
        #expect(items["t"] == md5Hex("secret" + salt))
    }

    @Test func songReturnsMappedTrack() async throws {
        let recorder = URLRequestRecorder(
            statusCode: 200,
            body:
                """
                {
                  "subsonic-response": {
                    "status": "ok",
                    "song": {
                      "id": "song-1",
                      "title": "Title",
                      "artist": "Artist",
                      "album": "Album",
                      "duration": 123,
                      "coverArt": "cover-1",
                      "starred": "2026-05-31T12:00:00Z"
                    }
                  }
                }
                """
        )
        let client = NavidromeAPIClient(credentials: try credentials(), session: recorder.session)

        let track = try #require(try await client.song(id: "song-1"))
        let request = try #require(recorder.lastRequest)
        let items = queryItems(from: try #require(request.url))

        #expect(items["id"] == "song-1")
        #expect(track == Track(
            id: "song-1",
            title: "Title",
            artist: "Artist",
            album: "Album",
            duration: 123,
            coverArtId: "cover-1",
            isFavorite: true
        ))
    }

    @Test func serverStatusFailureThrowsServerErrorMessage() async throws {
        let recorder = URLRequestRecorder(
            statusCode: 200,
            body:
                """
                {
                  "subsonic-response": {
                    "status": "failed",
                    "error": { "code": 40, "message": "Wrong credentials" }
                  }
                }
                """
        )
        let client = NavidromeAPIClient(credentials: try credentials(), session: recorder.session)

        await #expect(throws: IntegrationError.self) {
            _ = try await client.nowPlaying()
        }
    }

    @Test func httpFailureThrowsServerError() async throws {
        let recorder = URLRequestRecorder(statusCode: 503, body: "{}")
        let client = NavidromeAPIClient(credentials: try credentials(), session: recorder.session)

        await #expect(throws: IntegrationError.self) {
            _ = try await client.ping()
        }
    }

    private func credentials() throws -> NavidromeCredentials {
        NavidromeCredentials(
            serverURL: try #require(URL(string: "https://music.example.com")),
            username: "max",
            password: "secret"
        )
    }

    private func queryItems(from url: URL) -> [String: String] {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }

    private func md5Hex(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private final class URLRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var request: URLRequest?
    let session: URLSession

    var lastRequest: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return request
    }

    init(statusCode: Int, body: String) {
        let configuration = URLSessionConfiguration.ephemeral
        let handler = RequestHandler(statusCode: statusCode, body: Data(body.utf8)) { [weak self] request in
            self?.record(request)
        }
        configuration.protocolClasses = [handler.protocolClass]
        self.session = URLSession(configuration: configuration)
    }

    private func record(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        self.request = request
    }
}

private final class RequestHandler: @unchecked Sendable {
    let statusCode: Int
    let body: Data
    let record: @Sendable (URLRequest) -> Void
    let protocolClass: URLProtocol.Type

    init(statusCode: Int, body: Data, record: @escaping @Sendable (URLRequest) -> Void) {
        self.statusCode = statusCode
        self.body = body
        self.record = record

        final class ProtocolStub: URLProtocol {
            nonisolated(unsafe) static var handler: RequestHandler?

            override class func canInit(with request: URLRequest) -> Bool {
                true
            }

            override class func canonicalRequest(for request: URLRequest) -> URLRequest {
                request
            }

            override func startLoading() {
                guard let handler = Self.handler, let url = request.url else {
                    client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                    return
                }

                handler.record(request)
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: handler.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: handler.body)
                client?.urlProtocolDidFinishLoading(self)
            }

            override func stopLoading() {}
        }

        ProtocolStub.handler = self
        self.protocolClass = ProtocolStub.self
    }
}
