import AppKit
import SwiftUI

struct MenuBarMenuView: View {
    @ObservedObject private var model = PlayerModel.shared

    var body: some View {
        Group {
            if let snapshot = model.snapshot, !snapshot.isEmpty {
                Text(snapshot.name)
                Text("\(snapshot.artist) · \(snapshot.state == .playing ? "正在播放" : "已暂停")")
            } else if let error = model.errorMessage {
                Text(error)
            } else {
                Text("Apple Music 未在播放")
            }
        }

        Divider()

        Button {
            MiniPlayerPanelController.shared.toggle()
        } label: {
            Label(
                model.panelVisible ? "隐藏迷你播放器" : "显示迷你播放器",
                systemImage: "rectangle.on.rectangle"
            )
        }
        .keyboardShortcut("m", modifiers: [.command, .shift])

        Button {
            model.toggleMiniMode()
        } label: {
            Label(
                model.isMiniMode ? "展开完整播放器" : "收起为迷你模式",
                systemImage: model.isMiniMode ? "arrow.up.left.and.arrow.down.right" : "minus"
            )
        }

        Button {
            model.toggleLyrics()
        } label: {
            Label(
                model.lyricsVisible ? "隐藏桌面歌词" : "显示桌面歌词",
                systemImage: "text.quote"
            )
        }
        .keyboardShortcut("l", modifiers: [.command, .shift])

        if model.needsAutomationPermission {
            Button("打开自动化权限设置…") {
                model.openAutomationSettings()
            }
        }

        Button("打开 Apple Music") {
            model.openMusic()
        }

        Divider()

        Menu("歌词设置") {
            Button {
                model.nudgeLyricsOffset(-0.2)
            } label: {
                Label("歌词提前 0.2 秒", systemImage: "chevron.left")
            }

            Button {
                model.nudgeLyricsOffset(0.2)
            } label: {
                Label("歌词延迟 0.2 秒", systemImage: "chevron.right")
            }

            Text("当前偏移：\(offsetText) 秒")

            Button("重置歌词偏移") {
                model.resetLyricsOffset()
            }
            .disabled(abs(model.lyricsOffset) < 0.001)

            Button("恢复歌词默认位置") {
                model.resetLyricsPosition()
            }

            Divider()

            Menu("歌词字号") {
                Button {
                    model.setLyricsFontScale(0.85)
                } label: {
                    Label("小", systemImage: abs(model.lyricsFontScale - 0.85) < 0.01 ? "checkmark" : "")
                }
                Button {
                    model.setLyricsFontScale(1.0)
                } label: {
                    Label("标准", systemImage: abs(model.lyricsFontScale - 1.0) < 0.01 ? "checkmark" : "")
                }
                Button {
                    model.setLyricsFontScale(1.2)
                } label: {
                    Label("大", systemImage: abs(model.lyricsFontScale - 1.2) < 0.01 ? "checkmark" : "")
                }
            }

            Menu("歌词位置") {
                Button {
                    model.setLyricsAtTop(false)
                } label: {
                    Label("屏幕底部", systemImage: model.lyricsAtTop ? "" : "checkmark")
                }
                Button {
                    model.setLyricsAtTop(true)
                } label: {
                    Label("屏幕顶部", systemImage: model.lyricsAtTop ? "checkmark" : "")
                }
            }
        }

        Divider()

        Button {
            SupportWindowController.shared.show()
        } label: {
            Label("请作者喝杯咖啡…", systemImage: "cup.and.saucer.fill")
        }

        Divider()

        Button("退出音乐小窗") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var offsetText: String {
        String(format: "%+.1f", model.lyricsOffset)
    }
}
