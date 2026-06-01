import Foundation

enum IntegrationError: LocalizedError {
    case notConnected
    case unsupportedOperation(String)
    case missingCredentials
    case invalidResponse(String)
    case serverError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Provider is not connected."
        case .unsupportedOperation(let operation): return "Operation '\(operation)' is not supported."
        case .missingCredentials: return "Missing or invalid Navidrome credentials."
        case .invalidResponse(let message): return "Invalid response: \(message)"
        case .serverError(let message): return "Server error: \(message)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}
