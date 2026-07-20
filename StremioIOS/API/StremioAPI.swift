import Foundation

/// Low-level client for the Stremio account API (`https://api.strem.io/api/`).
///
/// Every call is a `POST` with a JSON body returning a `{ result, error }`
/// envelope. This layer knows nothing about UI or add-ons — it only speaks to the
/// account. Views must never call it directly (house rule: keep layers separate).
final class StremioAPI {
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL = URL(string: "https://api.strem.io/api/")!,
         session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom(Self.encodeStremioDate)
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeStremioDate)
        self.decoder = decoder
    }

    // MARK: - Endpoints

    func login(email: String, password: String) async throws -> AuthResult {
        try await post("login", body: LoginRequest(email: email, password: password))
    }

    func getAddons(authKey: String) async throws -> [AddonDescriptor] {
        let collection: AddonCollection = try await post(
            "addonCollectionGet",
            body: AddonCollectionGetRequest(authKey: authKey, update: true)
        )
        return collection.addons
    }

    func datastoreGet(authKey: String,
                      collection: String = "libraryItem") async throws -> [LibraryItem] {
        try await post("datastoreGet",
                       body: DatastoreGetRequest(authKey: authKey, collection: collection))
    }

    @discardableResult
    func datastorePut(authKey: String,
                      collection: String = "libraryItem",
                      changes: [LibraryItem]) async throws -> JSONValue {
        try await post("datastorePut",
                       body: DatastorePutRequest(authKey: authKey,
                                                 collection: collection,
                                                 changes: changes))
    }

    // MARK: - Core request

    private func post<Body: Encodable, Result: Decodable>(
        _ path: String, body: Body
    ) async throws -> Result {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(statusCode: http.statusCode, data: data)
        }

        let envelope: APIResponse<Result>
        do {
            envelope = try decoder.decode(APIResponse<Result>.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }

        if let apiError = envelope.error {
            throw APIError.api(code: apiError.code, message: apiError.message)
        }
        guard let result = envelope.result else {
            throw APIError.emptyResult
        }
        return result
    }

    // MARK: - Date handling
    // Stremio uses ISO8601, usually with milliseconds (e.g. 2020-01-01T00:00:00.000Z),
    // but sometimes without. Try both on read; always write with fractional seconds.

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func decodeStremioDate(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        if let date = iso8601WithFractional.date(from: string)
            ?? iso8601Plain.date(from: string) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unrecognized date format: \(string)"
        )
    }

    static func encodeStremioDate(_ date: Date, _ encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso8601WithFractional.string(from: date))
    }
}
