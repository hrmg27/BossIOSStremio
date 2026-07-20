import Foundation

/// Reads and writes playback state to the Stremio account library — the heart of
/// cross-device resume.
///
/// Reading powers "Continue Watching"; writing pushes the current playback
/// position so the PC and TV converge on the same resume point. Cross-device
/// merge is last-write-wins by `_mtime` (`mtime`), per stremio-core.
@MainActor
final class LibrarySync: ObservableObject {
    @Published private(set) var items: [LibraryItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private weak var session: AppSession?

    /// Wire up the session after construction (SwiftUI supplies it via the
    /// environment, which is not available at `init` time).
    func attach(session: AppSession) {
        self.session = session
    }

    /// Full library pull. Removed items are filtered out.
    func refresh() async {
        guard let session, let authKey = session.authKey else {
            errorMessage = APIError.notAuthenticated.errorDescription
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let all = try await session.api.datastoreGet(authKey: authKey)
            items = all.filter { !$0.removed }
        } catch {
            errorMessage = Self.message(from: error)
        }
    }

    /// Items with a meaningful in-progress position, most recently watched first.
    var continueWatching: [LibraryItem] {
        items
            .filter { $0.state.timeOffset > 0 && !$0.isFinished }
            .sorted {
                ($0.state.lastWatched ?? .distantPast) > ($1.state.lastWatched ?? .distantPast)
            }
    }

    /// Persist an updated playback position for a title. Called by the player on
    /// pause / background / exit. Bumps `mtime` so other devices adopt this state.
    func updateProgress(for itemID: String,
                        videoID: String?,
                        positionMs: Int,
                        durationMs: Int,
                        now: Date) async {
        guard let session, let authKey = session.authKey else { return }
        guard var item = items.first(where: { $0.id == itemID }) else { return }

        item.state.timeOffset = max(0, positionMs)
        if durationMs > 0 { item.state.duration = durationMs }
        if let videoID { item.state.videoID = videoID }
        item.state.lastWatched = now
        item.mtime = now
        item.temp = false

        do {
            try await session.api.datastorePut(authKey: authKey, changes: [item])
            if let index = items.firstIndex(where: { $0.id == itemID }) {
                items[index] = item
            }
        } catch {
            errorMessage = Self.message(from: error)
        }
    }

    private static func message(from error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
