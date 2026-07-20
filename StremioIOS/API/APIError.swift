import Foundation

/// Explicit error surface for the account API layer. The app is for real use, so
/// network and decoding failures are typed rather than swallowed.
enum APIError: Error, LocalizedError {
    case transport(Error)
    case invalidResponse
    case http(statusCode: Int, data: Data)
    case decoding(Error)
    case api(code: Int?, message: String)
    case emptyResult
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .transport(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        case .http(let statusCode, _):
            return "Server returned HTTP \(statusCode)."
        case .decoding:
            return "Could not read the server response."
        case .api(_, let message):
            return message
        case .emptyResult:
            return "The server returned an empty result."
        case .notAuthenticated:
            return "You are not signed in."
        }
    }
}
