import Foundation

/// A single library entry (movie or series) stored in the Stremio account
/// datastore under the `libraryItem` collection.
///
/// Field names confirmed against stremio-core `src/types/library/library_item.rs`.
/// We decode into this struct and re-encode it verbatim on write, so any fields we
/// do not model explicitly (`behaviorHints`) are preserved via `JSONValue`.
struct LibraryItem: Codable, Identifiable {
    let id: String
    var name: String
    var type: String
    /// Kept as the raw string; empty strings are valid and must round-trip.
    var poster: String?
    var posterShape: PosterShape
    var removed: Bool
    var temp: Bool
    var ctime: Date?
    var mtime: Date
    var state: LibraryItemState
    /// Not modeled explicitly; preserved verbatim for a faithful `datastorePut`.
    var behaviorHints: JSONValue?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case type
        case poster
        case posterShape
        case removed
        case temp
        case ctime = "_ctime"
        case mtime = "_mtime"
        case state
        case behaviorHints
    }
}

/// Poster aspect ratio hint. Defaults to `.poster` on unknown/missing values.
enum PosterShape: String, Codable {
    case poster
    case landscape
    case square

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? "poster"
        self = PosterShape(rawValue: raw) ?? .poster
    }
}
