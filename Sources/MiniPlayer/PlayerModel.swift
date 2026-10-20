import AppKit
import Foundation
import SwiftUI

@MainActor
final class PlayerModel: ObservableObject {
    static let shared = PlayerModel()

    @Published private(set) var snapshot: TrackSnapshot?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var accentColor: Color = .white
    @Published private(set) var lyrics: Lyrics?
    @Published private(set) var lyricsLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsAutomationPermission = false
    @Published private(set) var panelVisible = true
    @Published private(set) var isMiniMode = false
    @Published private(set) var lyricsVisible = false
    @Published private(set) var lyricsEditing = false
    @Published private(set) var lyricsOffset: Double = 0
    @Published private(set) var lyricsFontScale: Double = 1
    @Published private(set) var lyricsAtTop = false
    @Published private(set) var seekGeneration = 0

    private var pollTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var snapshotDate = Date()
    private var currentKey = ""
    private var isRefreshing = false
    private var pendingControls = 0
    private var stateRevision = 0
    private var controlTail: Task<Void, Never>?
    private var refreshDebounce: DispatchWorkItem?
    private let defaults = UserDefaults.standard

    private init() {
        isMiniMode = defaults.bool(forKey: "miniMode")
        lyricsVisible = defaults.bool(forKey: "lyricsVisible")
        // Offset 0 is meaningful now that we prefer real timed LRC files.
        // Reset the temporary +0.5s compensation once for existing installs.
        if defaults.integer(forKey: "lyricsOffsetVersion") < 1 {
            lyricsOffset = 0
            defaults.set(0, forKey: "lyricsOffset")
            defaults.set(1, forKey: "lyricsOffsetVersion")
        } else if let savedOffset = defaults.object(forKey: "lyricsOffset") as? Double {
            lyricsOffset = savedOffset
        } else {
            lyricsOffset = 0
        }
        if let savedScale = defaults.object(forKey: "lyricsFontScale") as? Double, savedScale > 0.4 {
            lyricsFontScale = savedScale
        }
        lyricsAtTop = defaults.bool(forKey: "lyricsAtTop")
    }

    // MARK: - Lifecycle

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        artworkTask?.cancel()
        lyricsTask?.cancel()
    }

    // MARK: - Derived values

    var isPlaying: Bool {
        snapshot?.state == .playing
    }

    var hasTrack: Bool {
        guard let snapshot else { return false }
        return !snapshot.isEmpty
    }

    var displayTitle: String {
        guard let snapshot, !snapshot.isEmpty else { return "未在播放" }
        return snapshot.name
    }

    var displaySubtitle: String {
        guard let snapshot, !snapshot.isEmpty else {
            return errorMessage ?? "打开 Apple Music 播放歌曲"
        }
        if !snapshot.artist.isEmpty { return snapshot.artist }
        if !snapshot.album.isEmpty { return snapshot.album }
        return "Apple Music"
    }

    var duration: TimeInterval {
        snapshot?.duration ?? 0
    }

    func estimatedPosition(at date: Date = Date()) -> TimeInterval {
        guard let snapshot else { return 0 }
        guard snapshot.state == .playing else { return snapshot.position }
        let elapsed = max(0, date.timeIntervalSince(snapshotDate))
        return min(snapshot.duration > 0 ? snapshot.duration : .greatestFiniteMagnitude, snapshot.position + elapsed)
    }

    func remaining(at date: Date = Date()) -> TimeInterval {
        max(0, duration - estimatedPosition(at: date))
    }

    /// Position used when matching lyric timestamps (manual offset included).
    func lyricsPosition(at date: Date = Date()) -> TimeInterval {
        max(0, estimatedPosition(at: date) + lyricsOffset)
    }

    /// Current lyric line, or nil when no timed lyrics are available.
    var currentLyricText: String? {
        guard let lyrics, !lyrics.lines.isEmpty else { return nil }
        let index = lyrics.index(at: lyricsPosition()) ?? 0
        return lyrics.lines[index].text
    }

    // MARK: - Polling

    func refresh() async {
        guard !isRefreshing, pendingControls == 0 else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let revision = stateRevision
        do {
            let fresh = try await MusicService.snapshot()
            // A control command may have been issued while the snapshot was
            // in flight. In that case this snapshot is stale and must not
            // overwrite the optimistic state.
            guard revision == stateRevision, pendingControls == 0 else { return }
            errorMessage = nil
            needsAutomationPermission = false

            guard let fresh else {
                clearCurrentTrack()
                return
            }

            if fresh.isEmpty {
                clearCurrentTrack()
                return
            }

            let key = fresh.cacheKey
            let isNewTrack = key != currentKey
            snapshot = fresh
            snapshotDate = Date()

            if isNewTrack {
                currentKey = key
                lyrics = nil
                lyricsLoading = true
                loadArtwork(for: fresh)
                loadLyrics(for: fresh)
            }
        } catch {
            handle(error)
        }
    }

    private func clearCurrentTrack() {
        guard snapshot != nil || !currentKey.isEmpty else { return }
        snapshot = nil
        artwork = nil
        accentColor = .white
        lyrics = nil
        lyricsLoading = false
        currentKey = ""
        artworkTask?.cancel()
        lyricsTask?.cancel()
    }

    // MARK: - Artwork

    private func loadArtwork(for track: TrackSnapshot) {
        artworkTask?.cancel()

        if let url = MusicService.cachedArtworkURL(for: track.cacheKey),
           let image = NSImage(contentsOf: url) {
            artwork = image
            accentColor = image.dominantAccentColor() ?? .white
            return
        }

        artwork = nil
        accentColor = .white
        let key = track.cacheKey

        artworkTask = Task { [weak self] in
            guard let self else { return }
            guard let url = await MusicService.fetchArtwork(for: key),
                  !Task.isCancelled,
                  self.currentKey == key,
                  let image = NSImage(contentsOf: url) else {
                return
            }
            self.artwork = image
            self.accentColor = image.dominantAccentColor() ?? .white
        }
    }

    // MARK: - Lyrics

    private func loadLyrics(for track: TrackSnapshot) {
        lyricsTask?.cancel()

        if let cached = LyricsService.cachedLyrics(for: track) {
            lyrics = cached
            lyricsLoading = false
            return
        }

        lyrics = nil
        lyricsLoading = true
        let key = track.cacheKey

        lyricsTask = Task { [weak self] in
            guard let self else { return }
            let fetched = await LyricsService.fetch(for: track)
            guard !Task.isCancelled, self.currentKey == key else { return }
            self.lyrics = fetched
            self.lyricsLoading = false
        }
    }

    // MARK: - Control serialization

    /// Music commands must not overlap: each osascript invocation can otherwise
    /// observe/apply a different player state and finish out of order.
    private func performControl(_ operation: @escaping () async throws -> Void) {
        enqueueControl { [weak self] in
            do {
                try await operation()
            } catch {
                self?.handle(error)
            }
        }
    }

    private func enqueueControl(_ operation: @escaping () async -> Void) {
        stateRevision &+= 1
        pendingControls += 1
        let previous = controlTail
        controlTail = Task { @MainActor [weak self] in
            _ = await previous?.value
            guard !Task.isCancelled else { return }
            await operation()
            self?.pendingControls = max(0, (self?.pendingControls ?? 1) - 1)
            self?.scheduleRefresh()
        }
    }

    private func scheduleRefresh() {
        refreshDebounce?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        refreshDebounce = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30, execute: item)
    }

    // MARK: - Controls

    func togglePlayPause() {
        guard var snap = snapshot, !snap.isEmpty else {
            openMusic()
            return
        }

        let wasPlaying = snap.state == .playing
        let shouldPlay = !wasPlaying
        let now = estimatedPosition()
        snap.position = now
        snap.state = shouldPlay ? .playing : .paused
        snapshot = snap
        snapshotDate = Date()

        performControl {
            try await MusicService.setPlayback(shouldPlay)
        }
    }

    func nextTrack() {
        guard hasTrack else { return }
        performControl {
            try await MusicService.nextTrack()
        }
    }

    func previousTrack() {
        guard hasTrack else { return }
        performControl {
            try await MusicService.previousTrack()
        }
    }

    func seek(to position: TimeInterval) {
        guard var snap = snapshot, !snap.isEmpty else { return }
        let target = min(max(0, position), snap.duration > 0 ? snap.duration : position)
        snap.position = target
        snapshot = snap
        snapshotDate = Date()
        seekGeneration += 1

        performControl {
            try await MusicService.seek(to: target)
        }
    }

    func toggleFavorite() {
        guard var snap = snapshot, !snap.isEmpty else { return }
        snap.favorited.toggle()
        snapshot = snap

        performControl {
            try await MusicService.setFavorited(snap.favorited)
        }
    }

    func openMusic() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
        if let app = running.first {
            app.activate(options: [.activateAllWindows])
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") else {
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    func openAutomationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Automation"
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    // MARK: - Window / lyric preferences

    func setPanelVisible(_ visible: Bool) {
        panelVisible = visible
    }

    func toggleMiniMode() {
        setMiniMode(!isMiniMode)
    }

    func setMiniMode(_ mini: Bool) {
        guard mini != isMiniMode else { return }
        isMiniMode = mini
        defaults.set(mini, forKey: "miniMode")
    }

    func toggleLyrics() {
        setLyricsVisible(!lyricsVisible)
    }

    func setLyricsVisible(_ visible: Bool) {
        lyricsVisible = visible
        defaults.set(visible, forKey: "lyricsVisible")
        if !visible, lyricsEditing {
            lyricsEditing = false
            DesktopLyricsWindowController.shared.setEditing(false)
        }
        DesktopLyricsWindowController.shared.setVisible(visible)
    }

    func setLyricsEditing(_ editing: Bool) {
        if editing, !lyricsVisible {
            lyricsVisible = true
            defaults.set(true, forKey: "lyricsVisible")
            DesktopLyricsWindowController.shared.setVisible(true)
        }
        lyricsEditing = editing
        DesktopLyricsWindowController.shared.setEditing(editing)
    }

    func resetLyricsPosition() {
        DesktopLyricsWindowController.shared.resetPosition()
    }

    func nudgeLyricsOffset(_ delta: Double) {
        let next = min(10, max(-10, lyricsOffset + delta))
        lyricsOffset = (next * 10).rounded() / 10
        defaults.set(lyricsOffset, forKey: "lyricsOffset")
    }

    func resetLyricsOffset() {
        lyricsOffset = 0
        defaults.set(0, forKey: "lyricsOffset")
    }

    func setLyricsFontScale(_ scale: Double) {
        lyricsFontScale = min(1.35, max(0.8, scale))
        defaults.set(lyricsFontScale, forKey: "lyricsFontScale")
        DesktopLyricsWindowController.shared.reposition()
    }

    func setLyricsAtTop(_ top: Bool) {
        lyricsAtTop = top
        defaults.set(top, forKey: "lyricsAtTop")
        DesktopLyricsWindowController.shared.resetPosition()
    }

    // MARK: - Errors

    private func handle(_ error: Error) {
        if let serviceError = error as? MusicServiceError {
            switch serviceError {
            case .automationDenied:
                needsAutomationPermission = true
                errorMessage = "需要允许「音乐小窗」控制 Apple Music"
            case .musicNotRunning:
                errorMessage = "Apple Music 没有运行"
            case .scriptFailed(let message):
                errorMessage = message
            }
        } else {
            errorMessage = error.localizedDescription
        }
    }
}
