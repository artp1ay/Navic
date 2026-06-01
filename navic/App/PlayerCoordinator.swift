import Foundation
import AppKit
import SwiftUI
import Observation
import OSLog

@MainActor
@Observable
final class PlayerCoordinator {

    private(set) var track: Track?
    private(set) var playbackState: PlaybackState = .empty
    private(set) var artwork: NSImage?
    private(set) var artworkTrackId: String?
    private(set) var isArtworkLoading: Bool = false
    private(set) var resolvedMode: ResolvedIntegrationMode = .disconnected
    private(set) var lastError: String?
    private(set) var isLoading: Bool = false

    @ObservationIgnored var widgetVisibilityDidChange: ((Bool) -> Void)?
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var stack: ProviderFactory.Stack
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var settingsObserverTask: Task<Void, Never>?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?
    @ObservationIgnored private var queuePrefetchTask: Task<Void, Never>?
    @ObservationIgnored private var providerSettingsSnapshot: ProviderSettingsSnapshot
    @ObservationIgnored private var idleStartedAt: Date?
    @ObservationIgnored private var consecutiveFailures: Int = 0
    @ObservationIgnored private var hasSucceededSinceLastRebuild: Bool = false
    @ObservationIgnored private var artworkGeneration: UInt64 = 0

    init(settings: AppSettings) {
        self.settings = settings
        self.stack = ProviderFactory(settings: settings).build()
        self.resolvedMode = stack.mode
        self.providerSettingsSnapshot = ProviderSettingsSnapshot(settings: settings)
    }

    // MARK: - Lifecycle

    func start() {
        stop()
        pollingTask = Task { [weak self] in
            await self?.pollLoop()
        }
        settingsObserverTask = Task { [weak self] in
            guard let stream = self?.settings.changes() else { return }
            var debounceTask: Task<Void, Never>?
            for await _ in stream {
                guard let self else { return }
                let nextSnapshot = ProviderSettingsSnapshot(settings: self.settings)
                guard nextSnapshot != self.providerSettingsSnapshot else { continue }
                self.providerSettingsSnapshot = nextSnapshot
                debounceTask?.cancel()
                debounceTask = Task { [weak self] in
                    // Short debounce just to coalesce the 4 didSets fired in the
                    // same frame by Apply (URL, username, password, ignoreSSL).
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run { self?.rebuildProviders() }
                }
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        settingsObserverTask?.cancel()
        settingsObserverTask = nil
        artworkTask?.cancel()
        artworkTask = nil
        queuePrefetchTask?.cancel()
        queuePrefetchTask = nil
    }

    func rebuildProviders() {
        stack = ProviderFactory(settings: settings).build()
        resolvedMode = stack.mode
        consecutiveFailures = 0
        hasSucceededSinceLastRebuild = false
        Task { await refreshOnce() }
        publishWidgetVisibility()
    }

    func refreshNow() {
        Task { await refreshOnce() }
    }

    // MARK: - Polling

    /// Foreground interval — runs while we're actively showing the widget and
    /// want sub-second responsiveness to track changes on the server.
    private static let fastPollInterval: TimeInterval = 0.25
    /// Background interval — runs while the widget is hidden or while we have no
    /// credentials. Keeps CPU/network minimal until the user is looking again.
    private static let slowPollInterval: TimeInterval = 3.0

    private func pollLoop() async {
        while !Task.isCancelled {
            await refreshOnce()
            let interval = currentPollInterval
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    private var currentPollInterval: TimeInterval {
        // Without credentials there's nothing to fetch — skip into a slow
        // heartbeat that just keeps the task alive in case settings change.
        guard stack.nowPlaying != nil else { return Self.slowPollInterval }
        // Persistent failure after a successful connection, or widget hidden by
        // user preference: drop to slow polling. Recover speed as soon as the
        // widget would become visible again.
        let lostConnection = hasSucceededSinceLastRebuild && consecutiveFailures >= Self.lostConnectionThreshold
        let widgetWouldBeHidden = settings.hideWidgetWhenIdle && shouldClearIdleTrack
        if lostConnection || widgetWouldBeHidden { return Self.slowPollInterval }
        return Self.fastPollInterval
    }

    private func refreshOnce() async {
        isLoading = true
        defer { isLoading = false }

        guard let nowPlaying = stack.nowPlaying else {
            withAnimation(.smooth(duration: 0.28)) {
                track = nil
                playbackState = .empty
                artwork = nil
                artworkTrackId = nil
                isArtworkLoading = false
            }
            consecutiveFailures = 0
            hasSucceededSinceLastRebuild = false
            publishWidgetVisibility()
            return
        }

        do {
            let snapshot = try await nowPlaying.snapshot()
            consecutiveFailures = 0
            hasSucceededSinceLastRebuild = true
            let newTrack = snapshot.track
            let newState = resolvedPlaybackState(snapshot.state, newTrack: newTrack)
            let displayTrack = newTrack ?? (shouldClearIdleTrack ? nil : track)

            if displayTrack?.id != track?.id {
                artworkTask?.cancel()
                artworkGeneration &+= 1
                let generation = artworkGeneration
                isArtworkLoading = displayTrack != nil && newTrack != nil
                if let newTrack {
                    if let artworkProvider = stack.artwork {
                        artworkTask = Task { [weak self] in
                            let image = try? await artworkProvider.artwork(for: newTrack, size: 768)
                            await MainActor.run {
                                // Use a generation counter rather than comparing track ids:
                                // if two rapid changes race, only the latest fetch wins.
                                guard let self, self.artworkGeneration == generation else { return }
                                withAnimation(.smooth(duration: 0.35)) {
                                    self.artwork = image
                                    self.artworkTrackId = newTrack.id
                                    self.isArtworkLoading = false
                                }
                            }
                        }
                    } else {
                        isArtworkLoading = false
                    }
                    prefetchUpcomingArtwork(after: newTrack)
                } else if shouldClearIdleTrack {
                    withAnimation(.smooth(duration: 0.28)) {
                        artwork = nil
                        artworkTrackId = nil
                        isArtworkLoading = false
                    }
                }
            }
            withAnimation(.easeInOut(duration: 0.28)) {
                track = displayTrack
                playbackState = newState
                lastError = nil
            }
            publishWidgetVisibility()
        } catch {
            consecutiveFailures += 1
            lastError = error.localizedDescription
            AppLog.player.error("Refresh failed: \(error.localizedDescription, privacy: .public)")
            publishWidgetVisibility()
        }
    }

    /// How many consecutive failures we tolerate after a known-good connection
    /// before hiding the widget. At 0.25s polling this is ≈2.5s of grace — long
    /// enough to ride out transient Wi-Fi blips, short enough to feel responsive.
    private static let lostConnectionThreshold = 10

    private func publishWidgetVisibility() {
        let hasCredentials = stack.nowPlaying != nil
        let lostConnection = hasSucceededSinceLastRebuild && consecutiveFailures >= Self.lostConnectionThreshold
        let shouldShow: Bool
        if !hasCredentials {
            // Server settings are missing or malformed — hide immediately.
            shouldShow = false
        } else if !hasSucceededSinceLastRebuild {
            // Just applied new settings and haven't reached the server yet —
            // stay hidden so we don't flash the widget with stale data.
            shouldShow = false
        } else if lostConnection {
            // We were connected, then the server stopped responding.
            shouldShow = false
        } else {
            shouldShow = !settings.hideWidgetWhenIdle || !shouldClearIdleTrack
        }
        widgetVisibilityDidChange?(shouldShow)
    }

    private func resolvedPlaybackState(_ state: PlaybackState, newTrack: Track?) -> PlaybackState {
        guard newTrack != nil else {
            guard track != nil else {
                idleStartedAt = nil
                return PlaybackState(status: .stopped)
            }

            if idleStartedAt == nil {
                idleStartedAt = Date()
            }

            return PlaybackState(
                status: .paused,
                elapsed: playbackState.elapsed,
                duration: playbackState.duration,
                updatedAt: state.updatedAt
            )
        }

        idleStartedAt = nil

        var resolved = state
        resolved.status = .playing
        return resolved
    }

    private var shouldClearIdleTrack: Bool {
        guard track != nil else { return true }
        guard playbackState.status == .paused else { return false }
        guard let idleStartedAt else { return false }
        return Date().timeIntervalSince(idleStartedAt) >= 60
    }

    private func prefetchUpcomingArtwork(after currentTrack: Track) {
        guard let apiClient = stack.apiClient else { return }
        queuePrefetchTask?.cancel()
        queuePrefetchTask = Task {
            guard let tracks = try? await apiClient.playQueueTracks(), !Task.isCancelled else { return }
            let upcoming = tracks
                .drop(while: { $0.id != currentTrack.id })
                .dropFirst()
                .prefix(3)
            for track in upcoming where !Task.isCancelled {
                _ = try? await apiClient.artwork(for: track, size: 768)
            }
        }
    }
}

private struct ProviderSettingsSnapshot: Equatable {
    let serverURLString: String
    let username: String
    let password: String
    let ignoreSSLErrors: Bool

    init(settings: AppSettings) {
        self.serverURLString = settings.serverURLString
        self.username = settings.username
        self.password = settings.password
        self.ignoreSSLErrors = settings.ignoreSSLErrors
    }
}
