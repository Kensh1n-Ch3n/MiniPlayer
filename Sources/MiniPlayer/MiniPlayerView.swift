import AppKit
import Combine
import SwiftUI

enum MiniMetrics {
    static let cardWidth: CGFloat = 352
    static let cardHeight: CGFloat = 170
    static let cornerRadius: CGFloat = 28
    static let shadowPadding: CGFloat = 8
    static let windowWidth = cardWidth + shadowPadding * 2
    static let windowHeight = cardHeight + shadowPadding * 2

    static let miniCardWidth: CGFloat = 300
    static let miniCardHeight: CGFloat = 56
    static let miniCornerRadius: CGFloat = 28
    static let miniWindowWidth = miniCardWidth + shadowPadding * 2
    static let miniWindowHeight = miniCardHeight + shadowPadding * 2

    static func cardSize(isMini: Bool) -> CGSize {
        isMini
            ? CGSize(width: miniCardWidth, height: miniCardHeight)
            : CGSize(width: cardWidth, height: cardHeight)
    }

    static func cardCornerRadius(isMini: Bool) -> CGFloat {
        isMini ? miniCornerRadius : cornerRadius
    }

    static func windowSize(isMini: Bool) -> CGSize {
        isMini
            ? CGSize(width: miniWindowWidth, height: miniWindowHeight)
            : CGSize(width: windowWidth, height: windowHeight)
    }
}

private extension View {
    func glassReadableShadow(_ intensity: Double = 1) -> some View {
        // Tight, glyph-shaped shadow. A large blur makes dense text merge into
        // a rectangle on the glass, so keep the falloff close to the glyphs.
        self
            .shadow(color: .black.opacity(0.54 * intensity), radius: 1.3, y: 0.9)
    }
}

struct MiniPlayerView: View {
    @EnvironmentObject private var model: PlayerModel
    @StateObject private var artworkHover = ArtworkHoverState.shared
    @State private var dragFraction: Double?
    @State private var hoveringProgress = false
    @State private var hoveringArtwork = false

    private var isMini: Bool { model.isMiniMode }
    private var cardCornerRadius: CGFloat { MiniMetrics.cardCornerRadius(isMini: isMini) }
    private var cardSize: CGSize { MiniMetrics.cardSize(isMini: isMini) }
    private var windowSize: CGSize { MiniMetrics.windowSize(isMini: isMini) }

    var body: some View {
        card
            .frame(width: cardSize.width, height: cardSize.height)
            .modifier(NativeGlassModifier(cornerRadius: cardCornerRadius))
            .saturation(1.25)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.035),
                        Color.clear,
                        Color.clear,
                        Color.white.opacity(0.018)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
            .padding(MiniMetrics.shadowPadding)
            .frame(width: windowSize.width, height: windowSize.height)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isMini)
    }

    private var card: some View {
        ZStack {
            if #unavailable(macOS 26.0) {
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow, state: .active)
            }

            if isMini {
                miniContent
            } else {
                fullContent
            }
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: isMini ? 96 : MiniMetrics.cardWidth * 0.38, height: 1)
                .blur(radius: 0.4)
                .padding(.top, 0.5)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            if isMini {
                miniProgressLine
                    .padding(.leading, 50)
                    .padding(.trailing, 40)
                    .padding(.bottom, 8)
            }
        }
    }

    private var fullContent: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 62)
            Color.clear.frame(height: 14)
            progressSection
                .frame(height: 14)
            controls
                .frame(height: 56)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var miniContent: some View {
        HStack(spacing: 6) {
            Button {
                    MiniPlayerPanelController.shared.hideAndOpenMusic()
                } label: {
                    AlbumArtworkView(
                        image: model.artwork,
                        size: 32,
                        cornerRadius: 16
                    )
                    .overlay {
                        if artworkHover.isHovered {
                            Circle()
                                .fill(Color.black.opacity(0.24))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.96))
                        }
                    }
                    .contentShape(Circle())
                    .scaleEffect(artworkHover.isHovered ? 1.06 : 1)
                    .animation(.easeOut(duration: 0.14), value: artworkHover.isHovered)
                }
                .buttonStyle(SoftPressButtonStyle())
                .help("打开 \(model.playerDisplayName)")
                .accessibilityLabel("打开 \(model.playerDisplayName)")
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(model.displayTitle)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .glassReadableShadow(0.9)

                Text(model.displaySubtitle)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .glassReadableShadow(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            .allowsHitTesting(false)
            .clipped()

            MiniTrackButton(
                systemName: "backward.fill",
                help: "上一首",
                disabled: !model.hasTrack,
                slideDirection: -1,
                action: model.previousTrack
            )

            MiniPlayPauseButton(
                isPlaying: model.isPlaying,
                action: model.togglePlayPause
            )

            MiniTrackButton(
                systemName: "forward.fill",
                help: "下一首",
                disabled: !model.hasTrack,
                slideDirection: 1,
                action: model.nextTrack
            )

            MiniModeButton(
                systemName: model.lyricsVisible ? "quote.bubble.fill" : "quote.bubble",
                help: model.lyricsVisible ? "隐藏桌面歌词" : "显示桌面歌词",
                action: model.toggleLyrics
            )

        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var miniProgressLine: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let duration = model.duration
            let position = model.estimatedPosition(at: context.date)
            let fraction: Double = duration > 0
                ? min(1, max(0, position / duration))
                : 0

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))

                    if fraction > 0 {
                        Capsule()
                            .fill(model.accentColor.opacity(0.9))
                            .frame(width: proxy.size.width * fraction)
                    }
                }
            }
            .frame(height: 2)
            .opacity(model.hasTrack ? 1 : 0.45)
            .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                MiniPlayerPanelController.shared.hideAndOpenMusic()
            } label: {
                AlbumArtworkView(image: model.artwork)
                    .frame(width: 62, height: 62)
                    .overlay {
                        if hoveringArtwork {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.22))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(SoftPressButtonStyle())
            .help("打开 \(model.playerDisplayName)")
            .accessibilityLabel("打开 \(model.playerDisplayName)")
            .onHover { hoveringArtwork = $0 }

            VStack(alignment: .leading, spacing: 3) {
                Text(model.displayTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .glassReadableShadow(0.9)

                HStack(spacing: 5) {
                    if model.needsAutomationPermission {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.yellow.opacity(0.9))
                    }
                    Text(model.displaySubtitle)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .glassReadableShadow(0.9)

            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()

            AudioBarsView(isPlaying: model.isPlaying)
                .frame(width: 28, height: 24, alignment: .trailing)
                .padding(.top, 1)
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            progressContent(at: context.date)
        }
    }

    private func progressContent(at date: Date) -> some View {
        let livePosition = model.estimatedPosition(at: date)
        let liveFraction: Double = {
            guard model.duration > 0 else { return 0 }
            return min(1, max(0, livePosition / model.duration))
        }()
        let fraction = dragFraction ?? liveFraction
        let shownPosition = dragFraction == nil ? livePosition : model.duration * fraction
        let remaining = max(0, model.duration - shownPosition)

        return HStack(spacing: 8) {
            Text(formattedTime(shownPosition))
                .font(.system(size: 10.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.96))
                .glassReadableShadow(0.9)
                .frame(width: 34, alignment: .leading)

            GeometryReader { proxy in
                progressBar(width: proxy.size.width, fraction: fraction)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard model.duration > 0 else { return }
                                let width = max(proxy.size.width, 1)
                                dragFraction = min(1, max(0, value.location.x / width))
                            }
                            .onEnded { value in
                                guard model.duration > 0 else {
                                    dragFraction = nil
                                    return
                                }
                                let width = max(proxy.size.width, 1)
                                let target = min(1, max(0, value.location.x / width))
                                dragFraction = nil
                                model.seek(to: model.duration * target)
                            }
                    )
            }
            .frame(height: 14)
            .allowsHitTesting(model.canSeek)

            Text("-" + formattedTime(remaining))
                .font(.system(size: 10.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.88))
                .glassReadableShadow(0.9)
                .frame(width: 38, alignment: .trailing)
        }
        .opacity(model.hasTrack ? 1 : 0.55)
    }

    private func progressBar(width: CGFloat, fraction: Double) -> some View {
        let clamped = min(1, max(0, fraction))
        let fillWidth = max(0, width * clamped)
        let barHeight: CGFloat = hoveringProgress || dragFraction != nil ? 8 : 7

        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(height: 7)

            if fillWidth > 0 {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.96),
                                Color.white.opacity(0.92),
                                model.accentColor.opacity(0.95)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth, height: 7)
                    .shadow(color: model.accentColor.opacity(0.38), radius: 5)
            }

            if dragFraction != nil {
                Circle()
                    .fill(Color.white)
                    .frame(width: 9, height: 9)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    .offset(x: max(0, min(width - 9, fillWidth - 4.5)))
            }
        }
        .frame(height: 13)
        .shadow(color: .black.opacity(0.32), radius: 3, y: 1)
        .scaleEffect(x: 1, y: barHeight / 7, anchor: .center)
        .animation(.easeOut(duration: 0.16), value: hoveringProgress)
        .onHover { hoveringProgress = $0 }
    }

    // MARK: - Controls

    private var controls: some View {
        ZStack {
            HStack(spacing: 8) {
                PlayerIconButton(
                    systemName: "backward.fill",
                    size: 22,
                    help: "上一首",
                    disabled: !model.hasTrack,
                    slideDirection: -1,
                    action: model.previousTrack
                )

                PlayPauseButton(isPlaying: model.isPlaying, disabled: false, action: model.togglePlayPause)

                PlayerIconButton(
                    systemName: "forward.fill",
                    size: 22,
                    help: "下一首",
                    disabled: !model.hasTrack,
                    slideDirection: 1,
                    action: model.nextTrack
                )
            }

            HStack(spacing: 0) {
                PlayerIconButton(
                    systemName: model.snapshot?.favorited == true ? "star.fill" : "star",
                    size: 20,
                    active: model.snapshot?.favorited == true,
                    activeColor: Color(red: 1.0, green: 0.83, blue: 0.38),
                    help: model.snapshot?.favorited == true ? "取消收藏" : "收藏",
                    disabled: !model.hasTrack || !model.canFavorite,
                    action: model.toggleFavorite
                )

                Spacer(minLength: 0)

                PlayerIconButton(
                    systemName: model.lyricsVisible ? "quote.bubble.fill" : "quote.bubble",
                    size: 20,
                    active: model.lyricsVisible,
                    activeColor: .white,
                    help: model.lyricsVisible ? "隐藏桌面歌词" : "显示桌面歌词",
                    action: model.toggleLyrics
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Artwork

private struct AlbumArtworkView: View {
    let image: NSImage?
    var size: CGFloat = 62
    var cornerRadius: CGFloat = 12

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius + 1, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.white.opacity(0.48))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 7, y: 3)
    }
}

// MARK: - Visualiser

private struct AudioBarsView: View {
    let isPlaying: Bool

    var body: some View {
        EqualizerView(isPlaying: isPlaying)
            .frame(width: 28, height: 24)
    }
}

// MARK: - Buttons

private struct PlayerIconButton: View {
    let systemName: String
    var size: CGFloat = 20
    var active = false
    var activeColor: Color = .white
    var help: String?
    var disabled = false
    var slideDirection: CGFloat?
    let action: () -> Void

    @State private var hovering = false
    @State private var slideOffset: CGFloat = 0
    @State private var slideOpacity: Double = 1
    @State private var slideTask: Task<Void, Never>?

    var body: some View {
        Button {
            if let direction = slideDirection, !disabled {
                slideTask?.cancel()
                withAnimation(.easeIn(duration: 0.09)) {
                    slideOffset = direction * 9
                    slideOpacity = 0
                }
                slideTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 90_000_000)
                    guard !Task.isCancelled else { return }
                    slideOffset = -direction * 9
                    withAnimation(.easeOut(duration: 0.15)) {
                        slideOffset = 0
                        slideOpacity = 1
                    }
                }
            }
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(active ? activeColor : Color.white.opacity(disabled ? 0.3 : 0.95))
                .glassReadableShadow(0.9)
                .offset(x: slideOffset)
                .opacity(slideOpacity)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
                .scaleEffect(hovering && !disabled ? 1.08 : 1)
                .opacity(disabled ? 0.92 : (hovering ? 1 : 0.94))
        }
        .buttonStyle(SoftPressButtonStyle())
        .disabled(disabled)
        .help(help ?? "")
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .onDisappear { slideTask?.cancel() }
    }
}

private struct PlayPauseButton: View {
    let isPlaying: Bool
    let disabled: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "play.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .offset(x: 1.5)
                    .opacity(isPlaying ? 0 : 1)
                    .scaleEffect(isPlaying ? 0.55 : 1)

                Image(systemName: "pause.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .opacity(isPlaying ? 1 : 0)
                    .scaleEffect(isPlaying ? 1 : 0.55)
            }
            .foregroundStyle(Color.white.opacity(disabled ? 0.35 : 0.98))
            .glassReadableShadow(0.9)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
            .scaleEffect(hovering ? 1.06 : 1)
            .opacity(hovering ? 1 : 0.96)
            .animation(.easeInOut(duration: 0.18), value: isPlaying)
        }
        .buttonStyle(SoftPressButtonStyle())
        .disabled(disabled)
        .help(isPlaying ? "暂停" : "播放")
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
    }
}



private struct SoftPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct MiniModeButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.94))
                .glassReadableShadow(0.85)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
                .scaleEffect(hovering ? 1.12 : 1)
                .opacity(hovering ? 1 : 0.9)
        }
        .buttonStyle(SoftPressButtonStyle())
        .help(help)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
    }
}

private struct MiniPlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .offset(x: 0.8)
                    .opacity(isPlaying ? 0 : 1)
                    .scaleEffect(isPlaying ? 0.55 : 1)

                Image(systemName: "pause.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(isPlaying ? 1 : 0)
                    .scaleEffect(isPlaying ? 1 : 0.55)
            }
            .foregroundStyle(Color.white.opacity(0.96))
            .glassReadableShadow(0.85)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .scaleEffect(hovering ? 1.12 : 1)
            .opacity(hovering ? 1 : 0.94)
            .animation(.easeInOut(duration: 0.16), value: isPlaying)
        }
        .buttonStyle(SoftPressButtonStyle())
        .help(isPlaying ? "暂停" : "播放")
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
    }
}

private struct MiniTrackButton: View {
    let systemName: String
    let help: String
    let disabled: Bool
    var slideDirection: CGFloat?
    let action: () -> Void

    @State private var hovering = false
    @State private var slideOffset: CGFloat = 0
    @State private var slideOpacity: Double = 1
    @State private var slideTask: Task<Void, Never>?

    var body: some View {
        Button {
            if let direction = slideDirection, !disabled {
                slideTask?.cancel()
                withAnimation(.easeIn(duration: 0.08)) {
                    slideOffset = direction * 7
                    slideOpacity = 0
                }
                slideTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    guard !Task.isCancelled else { return }
                    slideOffset = -direction * 7
                    withAnimation(.easeOut(duration: 0.13)) {
                        slideOffset = 0
                        slideOpacity = 1
                    }
                }
            }
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(disabled ? 0.3 : 0.92))
                .glassReadableShadow(0.85)
                .offset(x: slideOffset)
                .opacity(slideOpacity)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .scaleEffect(hovering && !disabled ? 1.14 : 1)
                .opacity(disabled ? 0.9 : (hovering ? 1 : 0.92))
        }
        .buttonStyle(SoftPressButtonStyle())
        .disabled(disabled)
        .help(help)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .onDisappear { slideTask?.cancel() }
    }
}
