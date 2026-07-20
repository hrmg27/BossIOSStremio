import Foundation

/// UI-facing conveniences derived from the raw library state.
extension LibraryItem {
    var posterURL: URL? {
        guard let poster, !poster.isEmpty else { return nil }
        return URL(string: poster)
    }

    /// The id to request streams for: the specific episode (e.g. `tt123:1:5`) when
    /// known, otherwise the item id (an imdb id for movies).
    var streamRequestID: String {
        state.videoID ?? id
    }

    /// Fraction watched, clamped to 0...1. Zero when duration is unknown.
    var progressFraction: Double {
        guard state.duration > 0 else { return 0 }
        return min(1, max(0, Double(state.timeOffset) / Double(state.duration)))
    }

    /// Considered finished when the resume position is within the last ~1.5% of
    /// the runtime (or the final 30 seconds), whichever is larger.
    var isFinished: Bool {
        guard state.duration > 0 else { return false }
        let remaining = state.duration - state.timeOffset
        return remaining <= max(30_000, state.duration / 66)
    }

    /// e.g. "12:34 / 1:02:00" — resume position over total runtime.
    var resumeLabel: String {
        "\(Self.formatTimestamp(ms: state.timeOffset)) / \(Self.formatTimestamp(ms: state.duration))"
    }

    static func formatTimestamp(ms: Int) -> String {
        let totalSeconds = max(0, ms) / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
