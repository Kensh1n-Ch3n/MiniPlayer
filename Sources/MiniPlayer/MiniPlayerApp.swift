import AppKit
import SwiftUI

@main
struct MiniPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = PlayerModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenuView()
        } label: {
            Image(systemName: model.isPlaying ? "waveform" : "music.note")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let model = PlayerModel.shared
        model.start()
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
