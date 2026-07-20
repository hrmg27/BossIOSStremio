import AVFoundation
import AVKit
import Foundation

/// Drives the embedded `AVPlayer` for one title.
///
/// This is the piece that closes the sync loop the project exists for:
/// 1. On ready → seek to the stored resume position.
/// 2. During playback → sample the position periodically.
/// 3. On pause / background / exit / end → write the position back to the account.
///
/// When `onPersistProgress` is nil the player is read-only (safe for demos before
/// real stream resolution exists) — it still resumes, but never writes.
@MainActor
final class PlayerViewModel: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var isReady = false
    @Published var errorMessage: String?

    private let target: PlaybackTarget
    private let onPersistProgress: ((_ positionMs: Int, _ durationMs: Int) async -> Void)?

    private var timeObserverToken: Any?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var hasResumed = false
    private var lastWrittenMs = 0

    /// Skip periodic writes closer together than this to avoid hammering the API.
    private let minWriteIntervalMs = 15_000

    init(target: PlaybackTarget,
         onPersistProgress: ((_ positionMs: Int, _ durationMs: Int) async -> Void)? = nil) {
        self.target = target
        self.onPersistProgress = onPersistProgress
    }

    // MARK: - Lifecycle

    func start() {
        configureAudioSession()

        let item = AVPlayerItem(url: target.streamURL)

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.resumeIfNeeded()
                    self.isReady = true
                    self.player.play()
                case .failed:
                    self.errorMessage = item.error?.localizedDescription ?? "Playback failed."
                default:
                    break
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.handlePlaybackEnded() }
        }

        player.replaceCurrentItem(with: item)
        addPeriodicTimeObserver()
    }

    /// Persist and tear down. Call on exit.
    func stop() async {
        await persistProgress(force: true)
        removeObservers()
        player.pause()
    }

    /// Persist the current position. `force` bypasses the write-interval throttle
    /// (used on pause / background / exit); periodic ticks pass `force: false`.
    func persistProgress(force: Bool = false) async {
        guard let onPersistProgress else { return }
        let positionMs = currentPositionMs()
        guard positionMs > 0 else { return }
        if !force, abs(positionMs - lastWrittenMs) < minWriteIntervalMs { return }
        lastWrittenMs = positionMs
        await onPersistProgress(positionMs, durationMs())
    }

    // MARK: - Resume

    private func resumeIfNeeded() {
        guard !hasResumed else { return }
        hasResumed = true
        guard target.startPositionMs > 0 else { return }
        let time = CMTime(value: Int64(target.startPositionMs), timescale: 1000)
        player.seek(to: time, toleranceBefore: .zero,
                    toleranceAfter: CMTime(seconds: 1, preferredTimescale: 1000))
    }

    // MARK: - Observation

    private func addPeriodicTimeObserver() {
        let interval = CMTime(seconds: 5, preferredTimescale: 1)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.persistProgress(force: false) }
        }
    }

    private func handlePlaybackEnded() async {
        // Persisting the full duration marks the item as finished for other devices.
        guard let onPersistProgress else { return }
        let dur = durationMs()
        guard dur > 0 else { return }
        lastWrittenMs = dur
        await onPersistProgress(dur, dur)
    }

    private func removeObservers() {
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    // MARK: - Helpers

    private func currentPositionMs() -> Int {
        let seconds = player.currentTime().seconds
        guard seconds.isFinite, seconds >= 0 else { return 0 }
        return Int(seconds * 1000)
    }

    private func durationMs() -> Int {
        guard let duration = player.currentItem?.duration, duration.isNumeric else { return 0 }
        let seconds = duration.seconds
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int(seconds * 1000)
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            // Non-fatal: foreground playback still works without background audio.
        }
    }
}
