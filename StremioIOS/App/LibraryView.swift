import SwiftUI

/// The signed-in home: a "Continue Watching" section (in-progress items ready to
/// resume) followed by the full library. This is the first visible proof that
/// login + library read work end to end.
struct LibraryView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var library = LibrarySync()
    @State private var playbackTarget: PlaybackTarget?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Stremio")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sign out", role: .destructive) {
                            session.logout()
                        }
                    }
                }
        }
        .task {
            library.attach(session: session)
            if library.items.isEmpty {
                await library.refresh()
            }
        }
        .fullScreenCover(item: $playbackTarget) { target in
            // Read-only until AddonClient resolves real streams: resume-seek is
            // exercised, but nothing is written back to the account.
            PlayerView(target: target)
        }
    }

    @ViewBuilder
    private var content: some View {
        if library.isLoading && library.items.isEmpty {
            ProgressView("Loading library…")
        } else if let error = library.errorMessage, library.items.isEmpty {
            VStack(spacing: 12) {
                Text(error).multilineTextAlignment(.center)
                Button("Retry") { Task { await library.refresh() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        } else {
            List {
                if !library.continueWatching.isEmpty {
                    Section("Continue Watching") {
                        ForEach(library.continueWatching) { item in
                            Button {
                                playbackTarget = item.demoPlaybackTarget
                            } label: {
                                ContinueWatchingRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("Library") {
                    ForEach(library.items) { item in
                        Text(item.name)
                    }
                }
            }
            .refreshable { await library.refresh() }
        }
    }
}

// MARK: - Temporary demo playback
// TODO: Remove once AddonClient resolves real streams. Until then, tapping a
// Continue Watching item plays a public sample HLS stream, seeking to the stored
// resume position so the resume-seek path can be validated end to end. No progress
// is written back (PlayerView is created without a persist closure), so the real
// account state is never touched by this demo.
private extension LibraryItem {
    var demoPlaybackTarget: PlaybackTarget {
        PlaybackTarget(
            id: id,
            videoID: state.videoID,
            title: name,
            streamURL: URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")!,
            startPositionMs: state.timeOffset
        )
    }
}

/// A single resumable title with poster, progress bar and a position/duration label.
private struct ContinueWatchingRow: View {
    let item: LibraryItem

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 46, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(2)
                ProgressView(value: item.progressFraction)
                Text(item.resumeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
