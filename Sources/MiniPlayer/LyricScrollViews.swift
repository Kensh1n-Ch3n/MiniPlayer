/// One-line lyric ticker: the outgoing line slides up while the new line
/// slides in from below.
struct VerticalLyricTicker: View {
    let text: String
    let font: Font
    let color: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .truncationMode(.tail)
                .id(text)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    )
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .animation(.easeInOut(duration: 0.24), value: text)
    }
}

import SwiftUI

/// Desktop lyric line. Only the current line is shown; changing lines slides
/// the old line up and the new line in from below.
struct VerticalLyricsView: View {
    let lines: [LyricLine]
    let current: Int
    let fontScale: CGFloat
    let accentColor: Color

    private var currentText: String {
        guard lines.indices.contains(current) else { return "" }
        return lines[current].text
    }

    var body: some View {
        ZStack {
            Text(currentText)
                .font(.system(size: 31 * fontScale, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .truncationMode(.tail)
                .shadow(color: .black.opacity(0.82), radius: 8, y: 2)
                .shadow(color: accentColor.opacity(0.38), radius: 18)
                .id(current)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .animation(.easeInOut(duration: 0.35), value: current)
    }
}
