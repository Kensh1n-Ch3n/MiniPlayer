import AppKit
import SwiftUI

enum MiniMetrics {
    static let cardWidth: CGFloat = 352
    static let cardHeight: CGFloat = 170
    static let cornerRadius: CGFloat = 28
    static let shadowPadding: CGFloat = 8
    static let windowWidth = cardWidth + shadowPadding * 2
    static let windowHeight = cardHeight + shadowPadding * 2
}

struct MiniPlayerView: View {
    @EnvironmentObject private var model: PlayerModel
    @State private var dragFraction: Double?
    @State private var hoveringProgress = false
    @State private var hoveringArtwork = false

    var body: some View {
        card
            .frame(width: MiniMetrics.cardWidth, height: MiniMetrics.cardHeight)
            .modifier(NativeGlassModifier(cornerRadius: MiniMetrics.cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: MiniMetrics.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MiniMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.72),
                                Color.white.opacity(0.22),
                                Color.white.opacity(0.38)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.8
                    )
            }
            .padding(MiniMetrics.shadowPadding)
            .frame(width: MiniMetrics.windowWidth, height: MiniMetrics.windowHeight)
    }

    private var card: some View {
        ZStack {
            if #unavailable(macOS 26.0) {
                BackdropBlurView(radius: 36)
                Color.black.opacity(0.20)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.03),
                        Color.clear,
                        Color.black.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        model.accentColor.opacity(0.10),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 430
                )
                .blendMode(.plusLighter)
            }

            VStack(spacing: 0) {
                header
                    .frame(height: 62)
                Color.clear.frame(height: 14)
                progressSection
                    .frame(height: 14)
                controls
                    .frame(height: 50)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)
        }
        .overlay(alignment: .top) {
            WindowDragHandle()
                .frame(width: 132, height: 28)
                .padding(.top, 2)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: MiniMetrics.cardWidth * 0.38, height: 1)
                .blur(radius: 0.4)
                .padding(.top, 0.5)
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
            .buttonStyle(.plain)
            .onHover { hoveringArtwork = $0 }
            .help("打开 Apple Music")
            .accessibilityLabel("打开 Apple Music")

            VStack(alignment: .leading, spacing: 3) {
                Text(model.displayTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .shadow(color: .black.opacity(0.46), radius: 6, y: 1)

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
                .shadow(color: .black.opacity(0.42), radius: 4, y: 1)

            }
            .frame(maxWidth: .infinity, alignment: .leading)

            AudioBarsView(isPlaying: model.isPlaying)
                .frame(width: 28, height: 24, alignment: .trailing)
                .padding(.top, 1)
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        let livePosition = model.estimatedPosition()
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
                .shadow(color: .black.opacity(0.65), radius: 4, y: 1)
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

            Text("-" + formattedTime(remaining))
                .font(.system(size: 10.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.88))
                .shadow(color: .black.opacity(0.65), radius: 4, y: 1)
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
                    action: model.previousTrack
                )

                PlayPauseButton(isPlaying: model.isPlaying, disabled: false, action: model.togglePlayPause)

                PlayerIconButton(
                    systemName: "forward.fill",
                    size: 22,
                    help: "下一首",
                    disabled: !model.hasTrack,
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
                    disabled: !model.hasTrack,
                    action: model.toggleFavorite
                )

                Spacer(minLength: 0)

                PlayerIconButton(
                    systemName: model.lyricsVisible ? "quote.bubble.fill" : "quote.bubble",
                    size: 20,
                    active: model.lyricsVisible,
                    activeColor: model.accentColor,
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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
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
        .frame(width: 62, height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(active ? activeColor : Color.white.opacity(disabled ? 0.3 : 0.95))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.white.opacity(hovering && !disabled ? 0.13 : 0.001))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help ?? "")
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

private struct PlayPauseButton: View {
    let isPlaying: Bool
    let disabled: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: isPlaying ? 28 : 26, weight: .semibold))
                .foregroundStyle(Color.white.opacity(disabled ? 0.35 : 0.98))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                .offset(x: isPlaying ? 0 : 1.5)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color.white.opacity(hovering ? 0.13 : 0.001))
                )
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(hovering ? 0.16 : 0.0), lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(isPlaying ? "暂停" : "播放")
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}


