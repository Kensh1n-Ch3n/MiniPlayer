import AppKit
import Combine
import ObjectiveC.runtime
import QuartzCore

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let lyricsView = LyricStatusView()
    private var cancellables = Set<AnyCancellable>()

    private let nowPlayingItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let nowPlayingSubtitleItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let panelItem = NSMenuItem(title: "", action: nil, keyEquivalent: "m")
    private let miniModeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let desktopLyricsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "l")
    private let menuBarLyricsItem = NSMenuItem(title: "在菜单栏显示歌词", action: nil, keyEquivalent: "")
    private let automationItem = NSMenuItem(title: "打开自动化权限设置…", action: nil, keyEquivalent: "")
    private let openMusicItem = NSMenuItem(title: "打开 Apple Music", action: nil, keyEquivalent: "")
    private let currentOffsetItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let resetOffsetItem = NSMenuItem(title: "重置歌词偏移", action: nil, keyEquivalent: "")
    private var fontSizeItems: [NSMenuItem] = []
    private var positionItems: [NSMenuItem] = []

    private override init() {
        statusItem = Self.makeStatusItem(length: 30)
        super.init()
        configureStatusItem()
        buildMenu()
        observeModel()
    }

    /// NSStatusBar has no public ordering API. The private priority variant is
    /// used (with a fallback) so the lyric item sits at the right edge of the
    /// third-party status area instead of being inserted left of older items.
    private static func makeStatusItem(length: CGFloat) -> NSStatusItem {
        let selector = NSSelectorFromString("_statusItemWithLength:withPriority:")
        let bar = NSStatusBar.system
        if bar.responds(to: selector),
           let method = class_getInstanceMethod(NSStatusBar.self, selector) {
            typealias Function = @convention(c) (AnyObject, Selector, CGFloat, Int) -> AnyObject?
            let implementation = unsafeBitCast(method_getImplementation(method), to: Function.self)
            if let item = implementation(bar, selector, length, Int(Int32.max)) as? NSStatusItem {
                return item
            }
        }
        return bar.statusItem(withLength: length)
    }

    func start() {
        updateStatusItemAppearance()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.toolTip = "音乐小窗"
        lyricsView.frame = button.bounds
        lyricsView.autoresizingMask = [.width, .height]
        lyricsView.isHidden = true
        lyricsView.hitTestView = nil
        button.addSubview(lyricsView)
        statusItem.menu = menu
        menu.delegate = self
    }

    private func observeModel() {
        PlayerModel.shared.$lyricsInMenuBar
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItemAppearance() }
            .store(in: &cancellables)
        PlayerModel.shared.$snapshot
            .map(\.?.state)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItemAppearance() }
            .store(in: &cancellables)
    }

    private func updateStatusItemAppearance() {
        let showLyrics = PlayerModel.shared.lyricsInMenuBar
        lyricsView.isHidden = !showLyrics
        if showLyrics {
            statusItem.length = 120
            statusItem.button?.image = nil
            statusItem.button?.title = ""
            statusItem.button?.layoutSubtreeIfNeeded()
            if let button = statusItem.button {
                lyricsView.frame = button.bounds
            }
            lyricsView.start()
        } else {
            lyricsView.stop()
            statusItem.length = 30
            statusItem.button?.title = ""
            statusItem.button?.image = NSImage(
                systemSymbolName: PlayerModel.shared.isPlaying ? "waveform" : "music.note",
                accessibilityDescription: "音乐小窗"
            )
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        nowPlayingItem.isEnabled = false
        nowPlayingSubtitleItem.isEnabled = false
        menu.addItem(nowPlayingItem)
        menu.addItem(nowPlayingSubtitleItem)
        menu.addItem(.separator())

        panelItem.target = self
        panelItem.action = #selector(togglePanel)
        panelItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(panelItem)

        miniModeItem.target = self
        miniModeItem.action = #selector(toggleMiniMode)
        menu.addItem(miniModeItem)

        desktopLyricsItem.target = self
        desktopLyricsItem.action = #selector(toggleDesktopLyrics)
        desktopLyricsItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(desktopLyricsItem)

        menuBarLyricsItem.target = self
        menuBarLyricsItem.action = #selector(toggleMenuBarLyrics)
        menu.addItem(menuBarLyricsItem)

        let dragHint = NSMenuItem(
            title: "提示：按住 ⌘ 拖动菜单栏歌词可调整位置",
            action: nil,
            keyEquivalent: ""
        )
        dragHint.isEnabled = false
        menu.addItem(dragHint)

        automationItem.target = self
        automationItem.action = #selector(openAutomationSettings)
        menu.addItem(automationItem)

        openMusicItem.target = self
        openMusicItem.action = #selector(openMusic)
        menu.addItem(openMusicItem)
        menu.addItem(.separator())

        let lyricsSettings = NSMenuItem(title: "歌词设置", action: nil, keyEquivalent: "")
        let lyricsMenu = NSMenu(title: "歌词设置")

        let advance = NSMenuItem(title: "歌词提前 0.2 秒", action: #selector(advanceLyrics), keyEquivalent: "")
        advance.target = self
        lyricsMenu.addItem(advance)
        let delay = NSMenuItem(title: "歌词延迟 0.2 秒", action: #selector(delayLyrics), keyEquivalent: "")
        delay.target = self
        lyricsMenu.addItem(delay)

        currentOffsetItem.isEnabled = false
        lyricsMenu.addItem(currentOffsetItem)

        resetOffsetItem.target = self
        resetOffsetItem.action = #selector(resetLyricsOffset)
        lyricsMenu.addItem(resetOffsetItem)

        let resetPosition = NSMenuItem(title: "恢复歌词默认位置", action: #selector(resetLyricsPosition), keyEquivalent: "")
        resetPosition.target = self
        lyricsMenu.addItem(resetPosition)
        lyricsMenu.addItem(.separator())

        let fontItem = NSMenuItem(title: "歌词字号", action: nil, keyEquivalent: "")
        let fontMenu = NSMenu(title: "歌词字号")
        for (index, title) in ["小", "标准", "大"].enumerated() {
            let item = NSMenuItem(title: title, action: #selector(setLyricsFontSize(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            fontMenu.addItem(item)
            fontSizeItems.append(item)
        }
        fontItem.submenu = fontMenu
        lyricsMenu.addItem(fontItem)

        let positionItem = NSMenuItem(title: "歌词位置", action: nil, keyEquivalent: "")
        let positionMenu = NSMenu(title: "歌词位置")
        for (index, title) in ["屏幕底部", "屏幕顶部"].enumerated() {
            let item = NSMenuItem(title: title, action: #selector(setLyricsPosition(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            positionMenu.addItem(item)
            positionItems.append(item)
        }
        positionItem.submenu = positionMenu
        lyricsMenu.addItem(positionItem)

        lyricsSettings.submenu = lyricsMenu
        menu.addItem(lyricsSettings)
        menu.addItem(.separator())

        let support = NSMenuItem(title: "请作者喝杯咖啡…", action: #selector(showSupport), keyEquivalent: "")
        support.target = self
        menu.addItem(support)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出音乐小窗", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    func menuWillOpen(_ menu: NSMenu) {
        let model = PlayerModel.shared
        if let snapshot = model.snapshot, !snapshot.isEmpty {
            nowPlayingItem.title = snapshot.name
            nowPlayingSubtitleItem.title = "\(snapshot.artist) · \(snapshot.state == .playing ? "正在播放" : "已暂停")"
        } else if let error = model.errorMessage {
            nowPlayingItem.title = error
            nowPlayingSubtitleItem.title = ""
        } else {
            nowPlayingItem.title = "Apple Music 未在播放"
            nowPlayingSubtitleItem.title = ""
        }

        panelItem.title = model.panelVisible ? "隐藏迷你播放器" : "显示迷你播放器"
        miniModeItem.title = model.isMiniMode ? "展开完整播放器" : "收起为迷你模式"
        desktopLyricsItem.title = model.lyricsVisible ? "隐藏桌面歌词" : "显示桌面歌词"
        menuBarLyricsItem.state = model.lyricsInMenuBar ? .on : .off
        openMusicItem.title = model.playbackSource == .netEaseMusic
            ? "打开网易云音乐"
            : "打开 Apple Music"
        automationItem.isHidden = !model.needsAutomationPermission
        currentOffsetItem.title = String(format: "当前偏移：%+.1f 秒", model.lyricsOffset)
        resetOffsetItem.isEnabled = abs(model.lyricsOffset) >= 0.001
        for (index, item) in fontSizeItems.enumerated() {
            let expected: Double = [0.85, 1.0, 1.2][index]
            item.state = abs(model.lyricsFontScale - expected) < 0.01 ? .on : .off
        }
        positionItems[0].state = model.lyricsAtTop ? .off : .on
        positionItems[1].state = model.lyricsAtTop ? .on : .off
    }

    @objc private func togglePanel() { MiniPlayerPanelController.shared.toggle() }
    @objc private func toggleMiniMode() { PlayerModel.shared.toggleMiniMode() }
    @objc private func toggleDesktopLyrics() { PlayerModel.shared.toggleLyrics() }
    @objc private func toggleMenuBarLyrics() { PlayerModel.shared.setLyricsInMenuBar(!PlayerModel.shared.lyricsInMenuBar) }
    @objc private func openAutomationSettings() { PlayerModel.shared.openAutomationSettings() }
    @objc private func openMusic() { PlayerModel.shared.openMusic() }
    @objc private func advanceLyrics() { PlayerModel.shared.nudgeLyricsOffset(-0.2) }
    @objc private func delayLyrics() { PlayerModel.shared.nudgeLyricsOffset(0.2) }
    @objc private func resetLyricsOffset() { PlayerModel.shared.resetLyricsOffset() }
    @objc private func resetLyricsPosition() { PlayerModel.shared.resetLyricsPosition() }
    @objc private func showSupport() { SupportWindowController.shared.show() }
    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func setLyricsFontSize(_ sender: NSMenuItem) {
        let scale: Double = [0.85, 1.0, 1.2][max(0, min(2, sender.tag))]
        PlayerModel.shared.setLyricsFontScale(scale)
    }

    @objc private func setLyricsPosition(_ sender: NSMenuItem) {
        PlayerModel.shared.setLyricsAtTop(sender.tag == 1)
    }
}

// MARK: - Smooth lyric view

private final class LyricStatusView: NSView {
    weak var hitTestView: NSView?
    private var timer: Timer?
    private var currentLine = ""
    private var previousLine: String?
    private var previousOffset: CGFloat = 0
    private var horizontalOffset: CGFloat = 0
    private var transitionStartedAt: CFTimeInterval = 0
    private var lineStartedAt: CFTimeInterval = 0
    private let font = NSFont.menuBarFont(ofSize: 13)
    private let gap: CGFloat = 32

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let text = PlayerModel.shared.currentLyricText ?? ""
        if text != currentLine {
            previousLine = currentLine.isEmpty ? nil : currentLine
            previousOffset = horizontalOffset
            transitionStartedAt = CACurrentMediaTime()
            lineStartedAt = transitionStartedAt
            currentLine = text
            horizontalOffset = 0
        }

        let padding: CGFloat = 6
        let width = measuredWidth(currentLine)
        let canScroll = width > bounds.width - padding * 2
        let maximumOffset = max(0, width - bounds.width + padding * 2)

        if canScroll {
            // Pause briefly at the start of each line so the beginning is
            // readable before the marquee starts. Scroll until the end of the
            // line is visible, then stop.
            if CACurrentMediaTime() - lineStartedAt >= 0.9 {
                horizontalOffset = min(maximumOffset, horizontalOffset + 1.0)
            }
        } else {
            horizontalOffset = 0
        }

        let progress: CGFloat
        if let previousLine {
            progress = min(1, CGFloat((CACurrentMediaTime() - transitionStartedAt) / 0.22))
            let previousWidth = measuredWidth(previousLine)
            let previousCanScroll = previousWidth > bounds.width - padding * 2
            let previousX = previousCanScroll
                ? padding - previousOffset
                : (bounds.width - previousWidth) / 2
            drawLine(previousLine, x: previousX, y: -progress * bounds.height, alpha: 1 - progress)
            if progress >= 1 {
                self.previousLine = nil
            }
        } else {
            progress = 1
        }

        let x = canScroll ? padding - horizontalOffset : (bounds.width - width) / 2
        drawLine(currentLine, x: x, y: (1 - progress) * bounds.height, alpha: 1)
    }

    private func drawLine(_ text: String, x: CGFloat, y: CGFloat, alpha: CGFloat) {
        guard !text.isEmpty, alpha > 0 else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byClipping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor.withAlphaComponent(alpha),
            .paragraphStyle: paragraph,
        ]
        (text as NSString).draw(at: NSPoint(x: x, y: y + 3), withAttributes: attributes)
    }

    private func measuredWidth(_ text: String) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }
}
