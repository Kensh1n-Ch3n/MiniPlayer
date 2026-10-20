import AppKit
import CoreImage
import QuartzCore
import SwiftUI

private let artworkColorContext = CIContext(options: nil)

let timelineReferenceDate = Date(timeIntervalSinceReferenceDate: 0)

extension NSImage {
    /// A saturated, readable accent colour sampled from the artwork.
    func dominantAccentColor() -> Color? {
        guard let tiff = tiffRepresentation,
              let input = CIImage(data: tiff) else {
            return nil
        }

        let extent = input.extent
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: input,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ]),
        let output = filter.outputImage else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        artworkColorContext.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        var color = NSColor(
            srgbRed: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1
        )
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return nil }
        color = rgb

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return Color(
            hue: Double(hue),
            saturation: min(0.92, max(0.42, Double(saturation))),
            brightness: min(0.95, max(0.62, Double(brightness)))
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = false
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
    }
}

struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView {
        DragView()
    }

    func updateNSView(_ view: DragView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

func formattedTime(_ value: TimeInterval) -> String {
    let total = max(0, Int(value.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%d:%02d", minutes, seconds)
}


// MARK: - Equalizer

struct EqualizerView: NSViewRepresentable {
    let isPlaying: Bool

    func makeNSView(context: Context) -> EqualizerNSView {
        let view = EqualizerNSView()
        view.isPlaying = isPlaying
        return view
    }

    func updateNSView(_ nsView: EqualizerNSView, context: Context) {
        nsView.isPlaying = isPlaying
    }
}

final class EqualizerNSView: NSView {
    private let heights: [CGFloat] = [10, 18, 24, 14, 20]
    private var bars: [CALayer] = []
    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 3

    var isPlaying = false {
        didSet {
            guard oldValue != isPlaying else { return }
            updateAnimation()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        for _ in heights {
            let bar = CALayer()
            bar.cornerRadius = 1.5
            bar.backgroundColor = NSColor.white.withAlphaComponent(0.34).cgColor
            bar.shadowColor = NSColor.black.cgColor
            bar.shadowOpacity = 0.45
            bar.shadowRadius = 2
            bar.shadowOffset = CGSize(width: 0, height: -1)
            layer?.addSublayer(bar)
            bars.append(bar)
        }
        updateAnimation()
    }

    override func layout() {
        super.layout()
        layoutBars()
    }

    private func layoutBars() {
        guard !bars.isEmpty else { return }
        let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * spacing
        let startX = max(0, bounds.width - totalWidth)

        for (index, bar) in bars.enumerated() {
            bar.anchorPoint = CGPoint(x: 0.5, y: 0)
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: heights[index])
            bar.position = CGPoint(
                x: startX + CGFloat(index) * (barWidth + spacing) + barWidth / 2,
                y: 0
            )
        }
    }

    private func updateAnimation() {
        if isPlaying {
            for (index, bar) in bars.enumerated() {
                bar.backgroundColor = NSColor.white.withAlphaComponent(0.84).cgColor
                guard bar.animation(forKey: "pulse") == nil else { continue }
                let animation = CABasicAnimation(keyPath: "transform.scale.y")
                animation.fromValue = 0.42
                animation.toValue = 1.0
                animation.duration = 0.44 + Double(index) * 0.075
                animation.autoreverses = true
                animation.repeatCount = .infinity
                animation.timeOffset = Double(index) * 0.13
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                bar.add(animation, forKey: "pulse")
            }
        } else {
            for bar in bars {
                bar.removeAnimation(forKey: "pulse")
                bar.transform = CATransform3DIdentity
                bar.backgroundColor = NSColor.white.withAlphaComponent(0.34).cgColor
            }
        }
    }
}
