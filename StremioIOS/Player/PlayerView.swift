import SwiftUI

/// Full-screen player screen. Persists progress when the app leaves the
/// foreground and when the view is dismissed.
struct PlayerView: View {
    @StateObject private var viewModel: PlayerViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(target: PlaybackTarget,
         onPersistProgress: ((_ positionMs: Int, _ durationMs: Int) async -> Void)? = nil) {
        _viewModel = StateObject(
            wrappedValue: PlayerViewModel(target: target, onPersistProgress: onPersistProgress)
        )
    }

    var body: some View {
        VideoPlayerContainer(player: viewModel.player)
            .ignoresSafeArea()
            .task { viewModel.start() }
            .onDisappear { Task { await viewModel.stop() } }
            .onChange(of: scenePhase) { phase in
                if phase != .active {
                    Task { await viewModel.persistProgress(force: true) }
                }
            }
            .overlay(alignment: .top) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.callout)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding()
                }
            }
    }
}
