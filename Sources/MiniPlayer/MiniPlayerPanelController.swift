import AppKit
import Combine
import CoreGraphics
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        var frame = super.constrainFrameRect(frameRect, to: screen)
        guard let target = screen ?? self.screen ?? NSScreen.main else { return frame }
        let visible = target.visibleFrame
        frame.origin.x = min(
            max(frame.origin.x, visible.minX),
            max(visible.minX, visible.maxX - frame.width)
        )
        frame.origin.y = min(
            max(frame.origin.y, visible.minY),
            max(visible.minY, visible.maxY - frame.height)
        )
        return frame
    }
}

@MainActor
final class MiniPlayerPanelController: NSObject, NSWindowDelegate {
    static let shared = MiniPlayerPanelController()

    private var panel: FloatingPanel?
    private let frameName = "MiniPlayerPanelFrame"
    private(set) var isVisible = false

    private var userHidden = false
    private var autoHiddenForMusic = false
    private var musicLaunchGraceUntil: Date?
    private var musicMonitorTask: Task<Void, Never>?
    private var miniModeCancellable: AnyCancellable?

    private override init() {
        super.init()
    }

    /// Called once at launch. The widget yields to a visible Music window.
    func start() {
        observeMiniMode()
        ensureMusicMonitor()
        if musicHasVisibleWindow() {
            autoHiddenForMusic = true
            hideWindow()
        } else {
            userHidden = false
            autoHiddenForMusic = false
            showWindow()
        }
    }

    /// User-initiated show (menu bar).
    func show() {
        userHidden = false
        ensureMusicMonitor()

        if musicHasVisibleWindow() {
            autoHiddenForMusic = true
            hideWindow()
            PlayerModel.shared.openMusic()
            return
        }

        autoHiddenForMusic = false
        showWindow()
    }

    /// User-initiated hide (menu bar).
    func hide() {
        userHidden = true
        autoHiddenForMusic = false
        hideWindow()
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Album artwork click: open Music and keep only one player UI on screen.
    func hideAndOpenMusic() {
        userHidden = false
        autoHiddenForMusic = true
        musicLaunchGraceUntil = Date().addingTimeInterval(3.5)
        hideWindow()
        PlayerModel.shared.openMusic()
        ensureMusicMonitor()
    }

    // MARK: - Mini mode

    private func observeMiniMode() {
        guard miniModeCancellable == nil else { return }
        miniModeCancellable = PlayerModel.shared.$isMiniMode
            .removeDuplicates()
            .sink { [weak self] isMini in
                self?.resizePanel(isMini: isMini, animated: true)
            }
    }

    private func resizePanel(isMini: Bool, animated: Bool) {
        guard let panel else { return }
        let targetSize = MiniMetrics.windowSize(isMini: isMini)
        guard abs(panel.frame.width - targetSize.width) > 0.5
            || abs(panel.frame.height - targetSize.height) > 0.5 else { return }

        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        var frame = NSRect(
            x: center.x - targetSize.width / 2,
            y: center.y - targetSize.height / 2,
            width: targetSize.width,
            height: targetSize.height
        )
        frame = panel.constrainFrameRect(frame, to: panel.screen ?? NSScreen.main)

        guard animated, isVisible else {
            panel.setFrame(frame, display: true)
            panel.saveFrame(usingName: frameName)
            return
        }

        let name = frameName
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        } completionHandler: { [weak panel] in
            panel?.saveFrame(usingName: name)
        }
    }

    // MARK: - Music presence

    private func ensureMusicMonitor() {
        guard musicMonitorTask == nil else { return }
        musicMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard let self, !Task.isCancelled else { return }
                self.evaluateMusicPresence()
            }
        }
    }

    private func evaluateMusicPresence() {
        if musicHasVisibleWindow() {
            musicLaunchGraceUntil = nil
            if isVisible {
                autoHiddenForMusic = true
                hideWindow()
            }
            return
        }

        guard !userHidden, autoHiddenForMusic else { return }
        if let grace = musicLaunchGraceUntil, Date() < grace { return }

        musicLaunchGraceUntil = nil
        autoHiddenForMusic = false
        if !isVisible {
            showWindow()
        }
    }

    private func musicHasVisibleWindow() -> Bool {
        guard let music = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.Music")
            .first else {
            return false
        }

        let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        for window in windows {
            guard let ownerPID = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  ownerPID == music.processIdentifier,
                  let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  layer == 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let width = (bounds["Width"] as? NSNumber)?.doubleValue,
                  let height = (bounds["Height"] as? NSNumber)?.doubleValue,
                  width >= 200,
                  height >= 100 else {
                continue
            }
            return true
        }
        return false
    }

    // MARK: - Panel lifecycle

    private func showWindow() {
        guard !isVisible else { return }
        let panel = ensurePanel()

        if !panel.setFrameUsingName(frameName) || !isOnVisibleScreen(panel.frame) {
            positionAtDefaultCorner(panel)
        }

        let targetSize = MiniMetrics.windowSize(isMini: PlayerModel.shared.isMiniMode)
        if abs(panel.frame.width - targetSize.width) > 0.5
            || abs(panel.frame.height - targetSize.height) > 0.5 {
            let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
            var frame = panel.frame
            frame.size = targetSize
            frame.origin = NSPoint(
                x: center.x - targetSize.width / 2,
                y: center.y - targetSize.height / 2
            )
            frame = panel.constrainFrameRect(frame, to: panel.screen ?? NSScreen.main)
            panel.setFrame(frame, display: true)
        }

        let constrained = panel.constrainFrameRect(panel.frame, to: panel.screen ?? NSScreen.main)
        if constrained != panel.frame {
            panel.setFrame(constrained, display: true)
        }

        panel.orderFrontRegardless()
        isVisible = true
        PlayerModel.shared.setPanelVisible(true)
    }

    private func hideWindow() {
        panel?.orderOut(nil)
        isVisible = false
        PlayerModel.shared.setPanelVisible(false)
    }

    private func ensurePanel() -> FloatingPanel {
        if let panel { return panel }

        let content = NSHostingView(
            rootView: MiniPlayerView()
                .environmentObject(PlayerModel.shared)
        )
        let initialSize = MiniMetrics.windowSize(isMini: PlayerModel.shared.isMiniMode)
        content.frame = NSRect(
            x: 0,
            y: 0,
            width: initialSize.width,
            height: initialSize.height
        )
        content.autoresizingMask = [.width, .height]

        let panel = FloatingPanel(
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
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .utilityWindow
        panel.delegate = self
        panel.setFrameAutosaveName(frameName)

        self.panel = panel
        return panel
    }

    private func positionAtDefaultCorner(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let x = visible.maxX - panel.frame.width - 18
        let y = visible.maxY - panel.frame.height - 20
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func isOnVisibleScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame.insetBy(dx: 40, dy: 40))
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }

        if let screen = panel.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            var frame = panel.frame
            frame.origin.x = min(
                max(frame.origin.x, visible.minX),
                max(visible.minX, visible.maxX - frame.width)
            )
            frame.origin.y = min(
                max(frame.origin.y, visible.minY),
                max(visible.minY, visible.maxY - frame.height)
            )
            if frame != panel.frame {
                panel.setFrame(frame, display: true)
            }
        }
        panel.saveFrame(usingName: frameName)
    }
}
