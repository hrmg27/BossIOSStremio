import SwiftUI

/// The signed-in root. Owns the shared `LibrarySync` and `AddonStore`, injects
/// them into the environment, and hosts the navigation stack.
struct HomeView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var library = LibrarySync()
    @StateObject private var addons = AddonStore()

    var body: some View {
        NavigationStack {
            LibraryListView()
                .navigationTitle("Stremio")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sign out", role: .destructive) {
                            session.logout()
                        }
                    }
                }
        }
        .environmentObject(library)
        .environmentObject(addons)
        .task {
            library.attach(session: session)
            addons.attach(session: session)
            await addons.load()
            if library.items.isEmpty {
                await library.refresh()
            }
        }
    }
}
