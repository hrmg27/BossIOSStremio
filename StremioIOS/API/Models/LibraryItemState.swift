import Foundation

/// Playback/progress state for a `LibraryItem`.
///
/// Field names confirmed against stremio-core
/// (`src/types/library/library_item.rs`). Time fields — `timeOffset`, `duration`,
/// `timeWatched`, `overallTimeWatched` — are in **milliseconds**. `timeOffset` is
/// the resume position; `duration` is the total runtime of the current video.
struct LibraryItemState: Codable {
    var lastWatched: Date?
    var timeWatched: Int
    var timeOffset: Int
    var overallTimeWatched: Int
    var timesWatched: Int
    var flaggedWatched: Int
    var duration: Int
    /// The specific video being watched (e.g. `tt1234567:1:5` for an episode).
    var videoID: String?
    /// Opaque bitfield of watched videos; preserved verbatim.
    var watched: String?
    var lastVidReleased: Date?
    var noNotif: Bool

    enum CodingKeys: String, CodingKey {
        case lastWatched
        case timeWatched
        case timeOffset
        case overallTimeWatched
        case timesWatched
        case flaggedWatched
        case duration
        case videoID = "video_id"
        case watched
        case lastVidReleased
        case noNotif
    }

    init() {
        lastWatched = nil
        timeWatched = 0
        timeOffset = 0
        overallTimeWatched = 0
        timesWatched = 0
        flaggedWatched = 0
        duration = 0
        videoID = nil
        watched = nil
        lastVidReleased = nil
        noNotif = false
    }

    // Tolerant decoding: the server always sends the numeric fields, but we default
    // them so a single unexpected shape never breaks the whole library read.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastWatched = (try? c.decodeIfPresent(Date.self, forKey: .lastWatched)) ?? nil
        timeWatched = try c.decodeIfPresent(Int.self, forKey: .timeWatched) ?? 0
        timeOffset = try c.decodeIfPresent(Int.self, forKey: .timeOffset) ?? 0
        overallTimeWatched = try c.decodeIfPresent(Int.self, forKey: .overallTimeWatched) ?? 0
        timesWatched = try c.decodeIfPresent(Int.self, forKey: .timesWatched) ?? 0
        flaggedWatched = try c.decodeIfPresent(Int.self, forKey: .flaggedWatched) ?? 0
        duration = try c.decodeIfPresent(Int.self, forKey: .duration) ?? 0
        videoID = try c.decodeIfPresent(String.self, forKey: .videoID)
        watched = try c.decodeIfPresent(String.self, forKey: .watched)
        lastVidReleased = (try? c.decodeIfPresent(Date.self, forKey: .lastVidReleased)) ?? nil
        noNotif = try c.decodeIfPresent(Bool.self, forKey: .noNotif) ?? false
    }
}
