import SwiftUI

/// Top-level gate: loading → login → content, driven by the session state.
struct RootView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        switch session.state {
        case .loading:
            ProgressView("Loading…")
        case .signedOut:
            LoginView()
        case .signedIn:
            HomeView()
        }
    }
}
