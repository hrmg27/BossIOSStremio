import SwiftUI

/// Continue Watching + full library, each row pushing a detail screen where the
/// user picks a stream to play.
struct LibraryListView: View {
    @EnvironmentObject private var library: LibrarySync

    var body: some View {
        content
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
                            NavigationLink {
                                TitleDetailView(item: item)
                            } label: {
                                ContinueWatchingRow(item: item)
                            }
                        }
                    }
                }
                Section("Library") {
                    ForEach(library.items) { item in
                        NavigationLink {
                            TitleDetailView(item: item)
                        } label: {
                            LibraryRow(item: item)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await library.refresh() }
        }
    }
}

/// A resumable title: poster, progress bar, position/duration label.
private struct ContinueWatchingRow: View {
    let item: LibraryItem

    var body: some View {
        HStack(spacing: 12) {
            PosterThumbnail(url: item.posterURL, width: 46, height: 68)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name).font(.headline).lineLimit(2)
                ProgressView(value: item.progressFraction)
                Text(item.resumeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A plain library entry: poster, name, type.
private struct LibraryRow: View {
    let item: LibraryItem

    var body: some View {
        HStack(spacing: 12) {
            PosterThumbnail(url: item.posterURL, width: 40, height: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).lineLimit(2)
                Text(item.type.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Small poster image with a neutral placeholder.
struct PosterThumbnail: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Color.gray.opacity(0.2)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
