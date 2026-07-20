import Foundation

/// Everything the player needs to open one title and resume it correctly.
struct PlaybackTarget: Identifiable {
    /// The owning `libraryItem` id (used when writing progress back).
    let id: String
    /// The specific video id (e.g. `tt1234567:1:5` for an episode), if known.
    let videoID: String?
    let title: String
    let streamURL: URL
    /// Resume position in milliseconds (0 = start from the beginning).
    let startPositionMs: Int
}
