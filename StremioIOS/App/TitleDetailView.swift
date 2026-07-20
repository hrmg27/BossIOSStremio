import SwiftUI

/// Title detail: shows resume info and the streams resolved from the installed
/// add-ons. Tapping a directly-playable stream opens the embedded player, which
/// writes real progress back to the account (the cross-device sync loop).
struct TitleDetailView: View {
    let item: LibraryItem

    @EnvironmentObject private var addons: AddonStore
    @EnvironmentObject private var library: LibrarySync

    @State private var streams: [AddonStream] = []
    @State private var isLoading = true
    @State private var playback: PlaybackTarget?

    var body: some View {
        List {
            Section { header }
            Section("Streams") { streamsSection }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await resolveStreams() }
        .fullScreenCover(item: $playback) { target in
            PlayerView(target: target) { positionMs, durationMs in
                await library.updateProgress(
                    for: item.id,
                    videoID: target.videoID,
                    positionMs: positionMs,
                    durationMs: durationMs,
                    now: Date()
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterThumbnail(url: item.posterURL, width: 80, height: 120)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name).font(.title3.bold())
                Text(item.type.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if item.state.timeOffset > 0 {
                    ProgressView(value: item.progressFraction)
                    Text("Resume at \(LibraryItem.formatTimestamp(ms: item.state.timeOffset))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var streamsSection: some View {
        if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                Text("Finding streams…").foregroundStyle(.secondary)
            }
        } else if streams.isEmpty {
            Text("No streams found from your installed add-ons for this title.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(Array(streams.enumerated()), id: \.offset) { _, stream in
                streamRow(stream)
            }
        }
    }

    private func streamRow(_ stream: AddonStream) -> some View {
        Button {
            play(stream)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.displayTitle).lineLimit(3)
                    if stream.isTorrent {
                        Text("Torrent — needs a debrid service (coming soon)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if stream.url != nil {
                    Image(systemName: "play.circle.fill").foregroundStyle(.tint)
                }
            }
        }
        .disabled(stream.url == nil)
    }

    private func play(_ stream: AddonStream) {
        guard let url = stream.url else { return }
        playback = PlaybackTarget(
            id: item.id,
            videoID: item.state.videoID,
            title: item.name,
            streamURL: url,
            startPositionMs: item.state.timeOffset
        )
    }

    private func resolveStreams() async {
        isLoading = true
        streams = await addons.streams(type: item.type, id: item.streamRequestID)
        isLoading = false
    }
}
