import AppKit
import CoreImage
import QuartzCore
import SwiftUI

/// A blur-only glass layer: it samples the desktop behind the window and
/// applies a Gaussian blur without adding the milky tint of system materials.
struct BackdropBlurView: NSViewRepresentable {
    var radius: CGFloat = 34

    func makeNSView(context: Context) -> BackdropBlurNSView {
        BackdropBlurNSView(radius: radius)
    }

    func updateNSView(_ view: BackdropBlurNSView, context: Context) {
        view.radius = radius
    }
}

final class BackdropBlurNSView: NSView {
    var radius: CGFloat {
        didSet { configureBlur() }
    }

    private var isBackdropLayer = false

    init(radius: CGFloat) {
        self.radius = radius
        super.init(frame: .zero)
        wantsLayer = true
        _ = layer
        configureBlur()
    }

    required init?(coder: NSCoder) {
        radius = 22
        super.init(coder: coder)
        wantsLayer = true
        configureBlur()
    }

    override func makeBackingLayer() -> CALayer {
        if let cls = NSClassFromString("CABackdropLayer") as? CALayer.Type {
            isBackdropLayer = true
            return cls.init()
        }
        return super.makeBackingLayer()
    }

    override func layout() {
        super.layout()
        layer?.frame = bounds
    }

    private func configureBlur() {
        guard let layer else { return }
        layer.masksToBounds = true
        layer.setValue(true, forKey: "allowsGroupBlending")
        layer.setValue(true, forKey: "windowServerAware")

        guard isBackdropLayer else { return }

        if let filterClass = NSClassFromString("CAFilter") as? NSObject.Type,
           let unmanaged = filterClass.perform(NSSelectorFromString("filterWithName:"), with: "gaussianBlur"),
           let filter = unmanaged.takeUnretainedValue() as? NSObject {
            filter.setValue(radius, forKey: "inputRadius")
            layer.filters = [filter]
            return
        }

        if let filter = CIFilter(name: "CIGaussianBlur") {
            filter.name = "miniblur.gaussian"
            filter.setValue(radius, forKey: kCIInputRadiusKey)
            layer.filters = [filter]
        }
    }
}
