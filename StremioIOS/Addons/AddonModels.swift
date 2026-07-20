import Foundation

/// `result` payload of `addonCollectionGet`.
struct AddonCollection: Decodable {
    let addons: [AddonDescriptor]
}

/// One installed add-on: where it lives plus its manifest.
struct AddonDescriptor: Decodable, Identifiable {
    let transportUrl: URL
    let manifest: AddonManifest
    var id: String { manifest.id }
}

/// The subset of an add-on manifest we need to route resource requests. Unknown
/// fields are ignored; missing arrays default to empty so one odd add-on cannot
/// break decoding of the whole collection.
struct AddonManifest: Decodable {
    let id: String
    let name: String
    let version: String?
    let resources: [ManifestResource]
    let types: [String]
    let idPrefixes: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, version, resources, types, idPrefixes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? id
        version = try c.decodeIfPresent(String.self, forKey: .version)
        resources = try c.decodeIfPresent([ManifestResource].self, forKey: .resources) ?? []
        types = try c.decodeIfPresent([String].self, forKey: .types) ?? []
        idPrefixes = try c.decodeIfPresent([String].self, forKey: .idPrefixes)
    }

    /// Whether this add-on advertises `resource` for the given `type`/`id`.
    func supports(resource: String, type: String, id: String) -> Bool {
        guard let match = resources.first(where: { $0.name == resource }) else { return false }
        // Resource-level scoping overrides manifest-level scoping when present.
        let scopedTypes = match.types ?? types
        guard scopedTypes.contains(type) else { return false }
        if let prefixes = match.idPrefixes ?? idPrefixes {
            return prefixes.contains { id.hasPrefix($0) }
        }
        return true
    }
}

/// A manifest `resources` entry: either a bare string ("stream") or an object with
/// per-resource type/idPrefix scoping.
struct ManifestResource: Decodable {
    let name: String
    let types: [String]?
    let idPrefixes: [String]?

    enum CodingKeys: String, CodingKey { case name, types, idPrefixes }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer().decode(String.self) {
            name = single
            types = nil
            idPrefixes = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        types = try c.decodeIfPresent([String].self, forKey: .types)
        idPrefixes = try c.decodeIfPresent([String].self, forKey: .idPrefixes)
    }
}

/// A playable stream from an add-on's `stream` resource. URLs are kept as raw
/// strings and parsed lazily so one malformed entry doesn't fail the whole list.
/// Named `AddonStream` to avoid clashing with Foundation's `Stream`.
struct AddonStream: Decodable {
    let urlString: String?
    let ytId: String?
    let infoHash: String?
    let fileIdx: Int?
    let externalUrlString: String?
    let name: String?
    let title: String?
    let description: String?
    let behaviorHints: StreamBehaviorHints?

    enum CodingKeys: String, CodingKey {
        case urlString = "url"
        case ytId
        case infoHash
        case fileIdx
        case externalUrlString = "externalUrl"
        case name
        case title
        case description
        case behaviorHints
    }

    var url: URL? { urlString.flatMap(URL.init(string:)) }
    var externalURL: URL? { externalUrlString.flatMap(URL.init(string:)) }

    /// Best human label for a stream row.
    var displayTitle: String {
        title ?? name ?? description ?? url?.host ?? "Stream"
    }

    /// Directly playable via AVPlayer (HTTP progressive / HLS).
    var isDirectlyPlayable: Bool { url != nil }

    /// A torrent needing a debrid resolver — no direct URL, only an infoHash.
    var isTorrent: Bool { url == nil && infoHash != nil }
}

struct StreamBehaviorHints: Decodable {
    let notWebReady: Bool?
    let bingeGroup: String?
    let proxyHeaders: JSONValue?

    enum CodingKeys: String, CodingKey { case notWebReady, bingeGroup, proxyHeaders }
}

struct StreamsResponse: Decodable {
    let streams: [AddonStream]
}

/// A subtitle track from an add-on's `subtitles` resource.
struct Subtitle: Decodable, Identifiable {
    let trackID: String?
    let urlString: String
    let lang: String

    enum CodingKeys: String, CodingKey {
        case trackID = "id"
        case urlString = "url"
        case lang
    }

    var id: String { trackID ?? urlString }
    var url: URL? { URL(string: urlString) }
}

struct SubtitlesResponse: Decodable {
    let subtitles: [Subtitle]
}
