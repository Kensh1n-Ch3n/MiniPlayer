import AppKit
import SwiftUI

struct SupportView: View {
    let qrImage: NSImage?

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(Color.orange)
                Text("请作者喝杯咖啡")
                    .font(.system(size: 22, weight: .bold))
            }

            Text("音乐小窗是免费的个人项目。\n如果它对你的日常有帮助，欢迎请我喝杯茶。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            if let qrImage {
                Image(nsImage: qrImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 260, height: 390)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    }
            }

            Text("打开支付宝扫一扫")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Button("关闭") {
                SupportWindowController.shared.close()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 380, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.light)
    }
}

@MainActor
final class SupportWindowController: NSObject, NSWindowDelegate {
    static let shared = SupportWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show() {
        let window = ensureWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }

        let qrURL = Bundle.main.url(forResource: "alipay-qr", withExtension: "jpg")
        let qrImage = qrURL.flatMap { NSImage(contentsOf: $0) }
        let content = NSHostingView(rootView: SupportView(qrImage: qrImage))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "支持作者"
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace]
        window.delegate = self
        window.center()

        self.window = window
        return window
    }
}
