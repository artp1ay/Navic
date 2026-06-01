import Foundation
import Testing
@testable import navic

struct NavidromeCredentialsTests {
    @Test func validityRequiresSchemeUsernameAndPassword() throws {
        let valid = NavidromeCredentials(
            serverURL: try #require(URL(string: "https://music.example.com")),
            username: "max",
            password: "secret"
        )
        #expect(valid.isValid)

        let missingScheme = NavidromeCredentials(
            serverURL: try #require(URL(string: "music.example.com")),
            username: "max",
            password: "secret"
        )
        #expect(!missingScheme.isValid)

        let missingUsername = NavidromeCredentials(
            serverURL: try #require(URL(string: "https://music.example.com")),
            username: "",
            password: "secret"
        )
        #expect(!missingUsername.isValid)

        let missingPassword = NavidromeCredentials(
            serverURL: try #require(URL(string: "https://music.example.com")),
            username: "max",
            password: ""
        )
        #expect(!missingPassword.isValid)
    }

    @Test func codableRoundTripPreservesAllFields() throws {
        let original = NavidromeCredentials(
            serverURL: try #require(URL(string: "https://music.example.com")),
            username: "max",
            password: "secret",
            ignoreSSLErrors: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NavidromeCredentials.self, from: data)

        #expect(decoded == original)
    }
}
