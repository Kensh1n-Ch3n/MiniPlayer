import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let model = PlayerModel.shared
        model.start()
        CachePruner.pruneInBackground()
        MenuBarController.shared.start()
        MiniPlayerPanelController.shared.start()

        if model.lyricsVisible {
            DesktopLyricsWindowController.shared.setVisible(true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PlayerModel.shared.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
