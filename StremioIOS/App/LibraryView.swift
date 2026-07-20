import SwiftUI

/// The signed-in home: a "Continue Watching" section (in-progress items ready to
/// resume) followed by the full library. This is the first visible proof that
/// login + library read work end to end.
struct LibraryView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var library = LibrarySync()

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
                            ContinueWatchingRow(item: item)
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
