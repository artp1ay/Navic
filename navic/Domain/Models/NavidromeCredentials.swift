import Foundation

struct NavidromeCredentials: Equatable, Codable {
    var serverURL: URL
    var username: String
    var password: String
    var ignoreSSLErrors: Bool = false

    var isValid: Bool {
        !username.isEmpty && !password.isEmpty && serverURL.scheme != nil
    }
}
