import AppKit
import Combine
import SwiftUI

// MARK: - Lyric timing

@MainActor
final class LyricsLineScheduler: ObservableObject {
    @Published private(set) var currentIndex: Int?
    private var task: Task<Void, Never>?
    private weak var model: PlayerModel?

    func restart(model: PlayerModel) {
        self.model = model
        task?.cancel()
        task = nil

        guard model.lyricsVisible,
              let lyrics = model.lyrics,
              !lyrics.lines.isEmpty else {
            currentIndex = nil
            return
        }

        let initialIndex = lyrics.index(at: model.lyricsPosition()) ?? 0
        currentIndex = initialIndex

        guard model.isPlaying else { return }

        task = Task { @MainActor [weak self] in
            guard let self else { return }
            var lastIndex = initialIndex
            let initialLyrics = lyrics

            while !Task.isCancelled {
                guard let model = self.model,
                      model.lyricsVisible,
                      model.isPlaying,
                      let latestLyrics = model.lyrics,
                      !latestLyrics.lines.isEmpty,
                      latestLyrics == initialLyrics else {
                    return
                }

                let position = model.lyricsPosition()
                let index = latestLyrics.index(at: position) ?? 0
                if index != lastIndex {
                    self.currentIndex = index
                    lastIndex = index
                }

                guard index + 1 < latestLyrics.lines.count else { return }
                let nextTime = latestLyrics.lines[index + 1].time
                let remaining = max(0.01, nextTime - position)
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
        }
    }

    func correctForExternalSeek(model: PlayerModel) {
        self.model = model
        guard model.isPlaying,
              let lyrics = model.lyrics,
              let displayed = currentIndex else {
            return
        }
        let actual = lyrics.index(at: model.lyricsPosition()) ?? 0
        if abs(actual - displayed) > 1 {
            restart(model: model)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        model = nil
        currentIndex = nil
    }
}

// MARK: - View

struct DesktopLyricsView: View {
    @EnvironmentObject private var model: PlayerModel
    @StateObject private var scheduler = LyricsLineScheduler()

    var body: some View {
        ZStack {
            if model.lyricsVisible {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if model.lyricsEditing {
                editingOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { scheduler.restart(model: model) }
        .onDisappear { scheduler.stop() }
        .onChange(of: model.lyrics) { _, _ in scheduler.restart(model: model) }
        .onChange(of: model.lyricsVisible) { _, _ in scheduler.restart(model: model) }
        .onChange(of: model.isPlaying) { _, _ in scheduler.restart(model: model) }
        .onChange(of: model.lyricsOffset) { _, _ in scheduler.restart(model: model) }
        .onChange(of: model.seekGeneration) { _, _ in scheduler.restart(model: model) }
        .onChange(of: model.snapshot) { _, _ in scheduler.correctForExternalSeek(model: model) }
    }

    @ViewBuilder
    private var content: some View {
        if let lyrics = model.lyrics, !lyrics.lines.isEmpty {
            let index = min(max(scheduler.currentIndex ?? 0, 0), lyrics.lines.count - 1)
            lyricsStack(lyrics, current: index)
        } else if model.lyricsLoading {
            statusPill(
                icon: nil,
                title: "正在为《\(model.displayTitle)》匹配歌词…",
                subtitle: nil,
                loading: true
            )
        } else if model.hasTrack {
            statusPill(
                icon: "text.quote",
                title: "没有找到这首歌的同步歌词",
                subtitle: "换一首歌试试，或稍后再打开桌面歌词",
                loading: false
            )
        } else {
            statusPill(
                icon: "music.note",
                title: "打开 Apple Music 播放歌曲",
                subtitle: "播放后会自动匹配桌面歌词",
                loading: false
            )
        }
    }

    private var editingOverlay: some View {
        ZStack {
            WindowDragHandle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.001))

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(0.40),
                    style: StrokeStyle(lineWidth: 1.2, dash: [7, 5])
                )
                .padding(7)
                .allowsHitTesting(false)

            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw.fill")
                    Text("拖动歌词调整位置")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
                Spacer()
            }
            .padding(.top, 8)
            .allowsHitTesting(false)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        PlayerModel.shared.setLyricsEditing(false)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("完成")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 18)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
    }

    private func lyricsStack(_ lyrics: Lyrics, current: Int) -> some View {
        VerticalLyricsView(
            lines: lyrics.lines,
            current: current,
            fontScale: model.lyricsFontScale,
            accentColor: model.accentColor
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }

    private func statusPill(icon: String?, title: String, subtitle: String?, loading: Bool) -> some View {
        HStack(spacing: 12) {
            if loading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(.white.opacity(0.8))
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 14, y: 5)
    }
}

// MARK: - Window

final class LyricsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Transparent draggable surface laid over the current lyric line.
/// The full-width lyric window itself stays click-through.
final class LyricsTextDragView: NSView {
    weak var lyricsWindow: NSWindow?
    var onDragEnd: (() -> Void)?

    private var startMouse = NSPoint.zero
    private var startLyricsOrigin = NSPoint.zero
    private var startSurfaceOrigin = NSPoint.zero

    override var mouseDownCanMoveWindow: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let surfaceWindow = window, let lyricsWindow else { return }
        startMouse = NSEvent.mouseLocation
        startLyricsOrigin = lyricsWindow.frame.origin
        startSurfaceOrigin = surfaceWindow.frame.origin
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let surfaceWindow = window, let lyricsWindow else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - startMouse.x
        let dy = current.y - startMouse.y

        var targetX = startLyricsOrigin.x + dx
        var targetY = startLyricsOrigin.y + dy

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(current) })
            ?? lyricsWindow.screen
            ?? NSScreen.main {
            let visible = screen.visibleFrame
            targetX = min(
                max(targetX, visible.minX),
                max(visible.minX, visible.maxX - lyricsWindow.frame.width)
            )
            targetY = min(
                max(targetY, visible.minY),
                max(visible.minY, visible.maxY - lyricsWindow.frame.height)
            )
        }

        let actualDX = targetX - startLyricsOrigin.x
        let actualDY = targetY - startLyricsOrigin.y
        lyricsWindow.setFrameOrigin(NSPoint(x: targetX, y: targetY))
        surfaceWindow.setFrameOrigin(NSPoint(
            x: startSurfaceOrigin.x + actualDX,
            y: startSurfaceOrigin.y + actualDY
        ))
    }

    override func mouseUp(with event: NSEvent) {
        NSCursor.openHand.set()
        onDragEnd?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
}

@MainActor
final class DesktopLyricsWindowController: NSObject, NSWindowDelegate {
    static let shared = DesktopLyricsWindowController()

    private var window: LyricsPanel?
    private var dragSurfaceWindow: NSPanel?
    private var saveTask: Task<Void, Never>?
    private var surfaceUpdateTask: Task<Void, Never>?
    private var lastSurfaceKey = ""
    private var screenObserver: NSObjectProtocol?
    private var lyricsCancellable: AnyCancellable?
    private var fontCancellable: AnyCancellable?
    private let defaults = UserDefaults.standard
    private let originXKey = "lyricsOriginX"
    private let originYKey = "lyricsOriginY"
    private let hasCustomOriginKey = "lyricsHasCustomOrigin"

    private override init() {
        super.init()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reposition()
            }
        }

        lyricsCancellable = PlayerModel.shared.$lyrics
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resizeWindowForLyrics()
            }
        fontCancellable = PlayerModel.shared.$lyricsFontScale
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resizeWindowForLyrics()
            }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func setVisible(_ visible: Bool) {
        if visible {
            let window = ensureWindow()
            reposition()
            window.ignoresMouseEvents = !PlayerModel.shared.lyricsEditing
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                window.animator().alphaValue = 1
            }
            if !PlayerModel.shared.lyricsEditing {
                showDragSurface()
            }
        } else {
            stopSurfaceUpdates()
            dragSurfaceWindow?.orderOut(nil)
            guard let window else { return }
            window.ignoresMouseEvents = true
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.14
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.orderOut(nil)
            })
        }
    }

    func setEditing(_ editing: Bool) {
        let panel: LyricsPanel
        if let window {
            panel = window
        } else {
            guard editing else { return }
            panel = ensureWindow()
        }

        panel.ignoresMouseEvents = !editing
        panel.isMovableByWindowBackground = editing
        panel.acceptsMouseMovedEvents = editing

        if editing {
            stopSurfaceUpdates()
            dragSurfaceWindow?.orderOut(nil)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        } else {
            saveOrigin()
            panel.resignKey()
            if PlayerModel.shared.lyricsVisible {
                showDragSurface()
            }
        }
    }

    func resetPosition() {
        defaults.removeObject(forKey: originXKey)
        defaults.removeObject(forKey: originYKey)
        defaults.removeObject(forKey: hasCustomOriginKey)
        reposition()
    }

    func windowDidMove(_ notification: Notification) {
        if PlayerModel.shared.lyricsEditing {
            saveOrigin()
        }
    }

    private func scheduleSaveOrigin() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.saveOrigin()
        }
    }

    private func saveOrigin() {
        guard let window else { return }
        defaults.set(window.frame.origin.x, forKey: originXKey)
        defaults.set(window.frame.origin.y, forKey: originYKey)
        defaults.set(true, forKey: hasCustomOriginKey)
    }

    private func showDragSurface() {
        guard PlayerModel.shared.lyricsVisible, !PlayerModel.shared.lyricsEditing else { return }
        _ = ensureDragSurfaceWindow()
        startSurfaceUpdates()
        updateDragSurface(force: true)
    }

    private func ensureDragSurfaceWindow() -> NSPanel {
        if let dragSurfaceWindow { return dragSurfaceWindow }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 44),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let view = LyricsTextDragView(frame: NSRect(x: 0, y: 0, width: 100, height: 44))
        view.autoresizingMask = [.width, .height]
        view.lyricsWindow = window
        view.onDragEnd = { [weak self] in
            Task { @MainActor in
                self?.saveOrigin()
                self?.updateDragSurface(force: true)
            }
        }
        panel.contentView = view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.delegate = self
        panel.ignoresMouseEvents = false

        dragSurfaceWindow = panel
        return panel
    }

    private func startSurfaceUpdates() {
        guard surfaceUpdateTask == nil else { return }
        surfaceUpdateTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if !PlayerModel.shared.lyricsVisible || PlayerModel.shared.lyricsEditing {
                    break
                }
                self.updateDragSurface(force: false)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            self?.surfaceUpdateTask = nil
        }
    }

    private func stopSurfaceUpdates() {
        surfaceUpdateTask?.cancel()
        surfaceUpdateTask = nil
    }

    private func updateDragSurface(force: Bool) {
        guard PlayerModel.shared.lyricsVisible,
              !PlayerModel.shared.lyricsEditing,
              let window,
              let lyric = PlayerModel.shared.currentLyricText,
              !lyric.isEmpty else {
            lastSurfaceKey = ""
            dragSurfaceWindow?.orderOut(nil)
            return
        }

        // Do not resize the surface while the user is holding the mouse button.
        if NSEvent.pressedMouseButtons != 0 && !force {
            return
        }

        let scale = PlayerModel.shared.lyricsFontScale
        let cacheKey = "\(lyric)|\(scale)|\(window.frame.origin.x),\(window.frame.origin.y)"
        if !force && cacheKey == lastSurfaceKey {
            return
        }
        lastSurfaceKey = cacheKey

        let font = NSFont.systemFont(ofSize: 31 * scale, weight: .bold)
        let paragraphs = lyric.components(separatedBy: "\n")
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let measuredWidth = paragraphs
            .map { ($0 as NSString).size(withAttributes: attributes).width }
            .max() ?? 0
        let availableWidth = max(120, window.frame.width - 60)
        let textWidth = min(measuredWidth, availableWidth)
        let estimatedVisualLines = max(
            paragraphs.count,
            min(2, Int(ceil(measuredWidth / availableWidth)))
        )
        let lineHeight = font.ascender - font.descender + font.leading
        let surfaceSize = NSSize(
            width: max(80, textWidth + 26),
            height: max(44, lineHeight * CGFloat(estimatedVisualLines) + 16)
        )

        var frame = NSRect(
            x: window.frame.midX - surfaceSize.width / 2,
            y: window.frame.midY - surfaceSize.height / 2,
            width: surfaceSize.width,
            height: surfaceSize.height
        )

        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(window.frame) }) {
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, visible.minX + 4), visible.maxX - frame.width - 4)
            frame.origin.y = min(max(frame.origin.y, visible.minY + 4), visible.maxY - frame.height - 4)
        }

        let panel = ensureDragSurfaceWindow()
        if let dragView = panel.contentView as? LyricsTextDragView {
            dragView.lyricsWindow = window
        }
        panel.setFrame(frame, display: false)
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func reposition() {
        guard let window else { return }
        window.setFrame(targetFrame(), display: true)
        updateDragSurface(force: true)
    }

    private func ensureWindow() -> LyricsPanel {
        if let window { return window }

        let content = NSHostingView(
            rootView: DesktopLyricsView()
                .environmentObject(PlayerModel.shared)
        )
        content.frame = NSRect(origin: .zero, size: targetFrame().size)
        content.autoresizingMask = [.width, .height]

        let panel = LyricsPanel(
            contentRect: content.frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = content
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = !PlayerModel.shared.lyricsEditing
        panel.isMovableByWindowBackground = PlayerModel.shared.lyricsEditing
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.delegate = self
        panel.setFrame(targetFrame(), display: false)

        window = panel
        return panel
    }

    private func lyricsWindowWidth(for screen: NSScreen) -> CGFloat {
        let visible = screen.visibleFrame
        let maximum = max(360, min(900, visible.width - 160))
        guard let lyrics = PlayerModel.shared.lyrics, !lyrics.lines.isEmpty else {
            return min(420, maximum)
        }

        let size = 31 * PlayerModel.shared.lyricsFontScale
        let font = NSFont.systemFont(ofSize: size, weight: .bold)
        let measured = lyrics.lines
            .map { ($0.text as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        return min(maximum, max(360, measured + 80))
    }

    private func resizeWindowForLyrics() {
        guard let window else { return }

        let screen = window.screen ?? NSScreen.main
        guard let screen else { return }
        let desired = lyricsWindowWidth(for: screen)
        let old = window.frame
        guard abs(desired - old.width) > 1 else { return }

        let visible = screen.visibleFrame
        var frame = old
        frame.size.width = desired
        frame.origin.x = min(
            max(old.midX - desired / 2, visible.minX),
            max(visible.minX, visible.maxX - desired)
        )
        window.setFrame(frame, display: true)
        updateDragSurface(force: true)
    }

    private func targetFrame() -> NSRect {
        let savedOrigin: NSPoint? = {
            guard defaults.bool(forKey: hasCustomOriginKey) else { return nil }
            return NSPoint(
                x: defaults.double(forKey: originXKey),
                y: defaults.double(forKey: originYKey)
            )
        }()

        let screen: NSScreen
        if let savedOrigin,
           let matching = NSScreen.screens.first(where: {
               $0.visibleFrame.insetBy(dx: -80, dy: -80).contains(savedOrigin)
           }) {
            screen = matching
        } else if let mainScreen = NSScreen.main ?? NSScreen.screens.first {
            screen = mainScreen
        } else {
            return NSRect(x: 0, y: 0, width: 1100, height: 150)
        }

        let visible = screen.visibleFrame
        let width = lyricsWindowWidth(for: screen)
        let height: CGFloat = 150

        if let savedOrigin {
            let x = min(max(savedOrigin.x, visible.minX), max(visible.minX, visible.maxX - width))
            let y = min(max(savedOrigin.y, visible.minY), max(visible.minY, visible.maxY - height))
            return NSRect(x: x, y: y, width: width, height: height)
        }

        let x = visible.midX - width / 2
        let y: CGFloat
        if PlayerModel.shared.lyricsAtTop {
            y = visible.maxY - height - 38
        } else {
            y = visible.minY + 34
        }
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
