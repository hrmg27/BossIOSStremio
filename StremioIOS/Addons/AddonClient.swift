import Foundation

/// Talks to individual add-ons over the Stremio Addon Protocol to resolve streams
/// and subtitles. Independent of the account API and of the UI: it takes the list
/// of installed add-ons (from `addonCollectionGet`) and fans out requests.
final class AddonClient {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public

    /// Streams for a title, gathered concurrently from every installed add-on that
    /// advertises the `stream` resource for this type/id.
    func streams(type: String, id: String,
                 from addons: [AddonDescriptor]) async -> [AddonStream] {
        let providers = addons.filter {
            $0.manifest.supports(resource: "stream", type: type, id: id)
        }
        return await gather(providers, resource: "stream", type: type, id: id) { data in
            try self.decoder.decode(StreamsResponse.self, from: data).streams
        }
    }

    /// Subtitles for a title, gathered concurrently across installed add-ons.
    func subtitles(type: String, id: String,
                   from addons: [AddonDescriptor]) async -> [Subtitle] {
        let providers = addons.filter {
            $0.manifest.supports(resource: "subtitles", type: type, id: id)
        }
        return await gather(providers, resource: "subtitles", type: type, id: id) { data in
            try self.decoder.decode(SubtitlesResponse.self, from: data).subtitles
        }
    }

    // MARK: - Internal

    private func gather<T>(_ providers: [AddonDescriptor],
                           resource: String, type: String, id: String,
                           decode: @escaping (Data) throws -> [T]) async -> [T] {
        await withTaskGroup(of: [T].self) { group in
            for addon in providers {
                guard let url = Self.resourceURL(base: addon.transportUrl,
                                                 resource: resource,
                                                 type: type, id: id) else { continue }
                group.addTask {
                    do {
                        let (data, response) = try await self.session.data(from: url)
                        guard let http = response as? HTTPURLResponse,
                              (200..<300).contains(http.statusCode) else { return [] }
                        return try decode(data)
                    } catch {
                        return []  // one add-on failing must not break the others
                    }
                }
            }
            var results: [T] = []
            for await chunk in group { results.append(contentsOf: chunk) }
            return results
        }
    }

    /// Builds `{base}/{resource}/{type}/{id}.json`, dropping `manifest.json` from
    /// the transport URL and percent-encoding path segments (ids contain colons,
    /// e.g. `tt1234567:1:5`).
    static func resourceURL(base transportUrl: URL, resource: String,
                            type: String, id: String) -> URL? {
        let baseDir = transportUrl.deletingLastPathComponent().absoluteString
        let encodedType = type.addingPercentEncoding(withAllowedCharacters: componentAllowed) ?? type
        let encodedID = id.addingPercentEncoding(withAllowedCharacters: componentAllowed) ?? id
        return URL(string: "\(baseDir)\(resource)/\(encodedType)/\(encodedID).json")
    }

    /// Mirrors JavaScript `encodeURIComponent` (unreserved characters only), so a
    /// colon in an episode id becomes `%3A` as the add-on SDK expects.
    private static let componentAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
