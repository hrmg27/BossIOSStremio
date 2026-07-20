import Foundation

/// Body for `POST /api/login`.
struct LoginRequest: Encodable {
    let type = "Login"
    let email: String
    let password: String
}

/// `result` payload returned by `/login`.
struct AuthResult: Decodable {
    let authKey: String
    let user: StremioUser
}

/// The account owner. Only the fields we actually use are modeled.
struct StremioUser: Decodable, Identifiable {
    let id: String
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email
    }
}

/// Generic `{ result, error }` envelope wrapping every account API response.
struct APIResponse<T: Decodable>: Decodable {
    let result: T?
    let error: APIErrorPayload?
}

struct APIErrorPayload: Decodable {
    let code: Int?
    let message: String
}
