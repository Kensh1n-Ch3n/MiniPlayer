<div align="center">

<img src="macos/docs/banner.png" alt="MiniPlayer for macOS and Windows" width="100%">

# MiniPlayer for Apple Music

**A floating player for macOS and Windows: macOS supports Apple Music and NetEase Cloud Music; Windows currently supports NetEase Cloud Music.**

English | [简体中文](README.md)

<p>
  <a href="https://github.com/Kensh1n-Ch3n/MiniPlayer/releases/latest"><img alt="Release" src="https://img.shields.io/badge/Release-v1.3.0-blueviolet?style=flat-square"></a>
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple">
  <img alt="Windows" src="https://img.shields.io/badge/Windows-10%2F11-0078D6?style=flat-square&logo=windows">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift">
  <img alt="Liquid Glass" src="https://img.shields.io/badge/UI-Liquid%20Glass-8A2BE2?style=flat-square">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/License-MIT-green?style=flat-square"></a>
  <a href="https://github.com/Kensh1n-Ch3n/MiniPlayer"><img alt="GitHub" src="https://img.shields.io/badge/GitHub-MiniPlayer-181717?style=flat-square&logo=github"></a>
  <a href="#-support-the-author"><img alt="Buy Me a Coffee" src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-Support-ffdd00?style=flat-square&logo=buymeacoffee&logoColor=black"></a>
</p>

<p>
  <a href="#-macos-features">macOS Features</a> ·
  <a href="#-macos-screenshots">macOS Screenshots</a> ·
  <a href="#-macos-installation">macOS Installation</a> ·
  <a href="#-windows-version">Windows Version</a> ·
  <a href="#-macos-usage">macOS Usage</a> ·
  <a href="#-lyrics-and-sync">Lyrics &amp; Sync</a> ·
  <a href="#-resource-usage--cache">Resource Usage</a> ·
  <a href="#-faq">FAQ</a> ·
  <a href="#-license">License</a> ·
  <a href="#-support-the-author">Support</a>
</p>

</div>

---

## ✨ macOS Features

- **Two playback sources**: Apple Music and NetEase Cloud Music. The app uses system Now Playing to follow the active player automatically, including track changes, pause/play, lyrics, and artwork.
- **Native Liquid Glass**: macOS 26+ uses SwiftUI's `.glassEffect(.clear, in:)` for system refraction, blur, and edge highlights; macOS 14–15 falls back to a custom blur.
- **Mini capsule mode**: double-click empty card space to switch between the full player and the 300×56 capsule. The capsule keeps artwork, title, previous / play-pause / next, lyrics and a thin progress line. Click the artwork to open the active player; hovering shows a highlight and an open arrow.
- **Full playback controls**: favorite, previous, play / pause, next; the progress bar supports click and drag seeking.
- **Lightweight transitions**: play/pause and previous/next use directional transition animations for clear feedback.
- **Artwork interaction**: click the artwork to open the active player. With Apple Music the widget hides; with NetEase it stays visible. Hovering shows an open affordance.
- **Single-line desktop lyrics**: only the current line is shown — no previous or next line. The window adapts to lyric length for easier horizontal dragging. Toggle with the lyrics button at the lower-right of the player.
- **Menu bar lyrics**: while playing, the current line appears in the menu bar; when paused or stopped, the icon is shown instead. Long lines scroll smoothly and stop at the end without looping.
- **Drag lyrics directly**: drag the desktop lyric text itself; the position is saved automatically.
- **Lyric matching**: Apple Music uses Apple's official timeline; NetEase uses NetEase's lyric service; if that source has no lyrics, the app falls back to LRCLIB and other sources.
- **Original language first**: Traditional Chinese is converted to Simplified Chinese; English, Korean, and Japanese keep their original text.
- **On-screen bounds**: the player card and desktop lyrics stay within the visible screen area.
- **Low overhead**: about **40 MB** resident memory; playback and lyric rendering stay lightweight.

## 📸 macOS Screenshots

<p align="center">
  <b>Full Liquid Glass player</b><br><br>
  <img src="macos/docs/ui-full.png" alt="Full Liquid Glass player" width="82%">
</p>

<p align="center">
  <b>Single-line desktop lyrics</b><br><br>
  <img src="macos/docs/ui-lyrics.png" alt="Single-line desktop lyrics" width="100%">
</p>

<p align="center">
  <b>Menu bar lyrics</b><br><br>
  <img src="macos/docs/ui-menubar.png" alt="Menu bar lyrics" width="100%">
</p>

<p align="center">
  <b>Mini capsule mode</b><br><br>
  <img src="macos/docs/ui-mini.png" alt="Mini capsule mode" width="72%">
</p>

> Native glass samples the windows behind it in real time. A photo or wallpaper behind it produces blurred colors; a white window behind it makes it look white. This is how system glass behaves.

## 🚀 macOS Installation

### Download

1. Download and unzip [MiniPlayer.zip](https://github.com/Kensh1n-Ch3n/MiniPlayer/releases/latest/download/MiniPlayer.zip).
2. Drag `MiniPlayer.app` into your Applications folder.
3. Double-click to open it.

On first launch, macOS will ask:

> "MiniPlayer.app" wants to control "Music.app" (Apple Music only)

Choose **Allow**. If you accidentally choose "Don't Allow", open **Automation Permission Settings…** from the MiniPlayer menu bar menu, or go to:

`System Settings → Privacy & Security → Automation → MiniPlayer → Music`

### Requirements

- macOS 14 or later
- Apple Music and/or NetEase Cloud Music
- Native Liquid Glass requires macOS 26+; older systems automatically use the fallback glass effect

## 🎮 macOS Usage

| Action | How |
| --- | --- |
| Move the player | Drag the empty top area of the card |
| Open the active player | Click the album artwork; with Apple Music the widget hides, while with NetEase it stays visible |
| Show / hide the player | Menu bar music icon, `⌘⇧M` |
| Collapse to mini mode | Double-click empty card space, or menu bar → Collapse to Mini Mode |
| Expand the full player | Double-click empty card space, or menu bar → Expand Full Player |
| Show / hide desktop lyrics | Lyrics button at the lower-right of the card, `⌘⇧L` |
| Show / hide menu bar lyrics | Menu bar menu → Show Lyrics in Menu Bar |
| Reposition menu bar lyrics | Hold `⌘` and drag the menu bar lyric item |
| Move desktop lyrics | Drag the lyric text directly |
| Adjust lyric timing | Menu bar → Lyrics Settings → 0.2s earlier / later |
| Adjust lyric size / position | Menu bar → Lyrics Settings |
| Support the author | Menu bar → Buy Me a Coffee… |
| Quit | Menu bar → Quit MiniPlayer, `⌘Q` |

## 🎵 Lyrics and Sync

### Source priority

1. **Apple Music official TTML cache**: when Music plays a track, it caches official line-synced lyrics locally. MiniPlayer parses Apple's own timeline. This is the default zero-offset source.
2. **LRCLIB**: if Apple has no cache, use LRCLIB synced LRC.
3. **NetEase Cloud Music LRC**: used when LRCLIB only has plain text.
4. **Embedded Apple Music lyrics / estimated timing**: final fallback; alignment is not guaranteed without a real timeline.

Lyrics cache directory: `~/Library/Caches/MiniPlayer/lyrics`

### About offsets

- Tracks with a real timeline are **aligned at offset 0**.
- If a particular release has its own timing offset, adjust it in ±0.2s steps from the menu bar.
- English, Korean, and Japanese lyrics keep their original text; Chinese translations are no longer substituted.

## ⚡ Resource Usage & Cache

- About **40 MB** resident memory; only the current track's artwork and lyrics are kept in memory.
- Artwork cache: `~/Library/Caches/MiniPlayer/artwork`, capped at about **160 MB**.
- Lyric cache: `~/Library/Caches/MiniPlayer/lyrics`, capped at about **32 MB**.
- Caches older than **30 days** are pruned at launch; when a cap is exceeded, the oldest files are removed first.

## 🛠️ macOS Build from Source

Requires Xcode 15+ and Swift 5.9+.

```bash
cd macos
./scripts/build.sh
```

Build outputs:

- `dist/MiniPlayer.app`
- `dist/MiniPlayer.zip`

The app prefers an available local Apple Development certificate; without one it falls back to ad-hoc signing. It only uses system frameworks and has no third-party runtime dependencies.

## 🪟 Windows Version

The Windows project lives in `windows/` and currently supports **NetEase Cloud Music only**.

- System Media Transport Controls (SMTC) metadata: title, artist, artwork, position, playback state
- Play/pause, previous, next, seeking
- Full / mini floating player, single-line desktop lyrics, tray menu
- DWM Acrylic, rounded corners, translucent gradients and inner highlights for a glass look. It follows the layering approach of [pratikone/liquid-glass-WinUI](https://github.com/pratikone/liquid-glass-WinUI); full Win2D refraction would require a WinUI 3 host, so this Avalonia build is an approximation.

Build from `windows/`:

```bash
dotnet build -c Release
dotnet publish -c Release -r win-x64 --self-contained true -o publish/win-x64
```

The Windows port is experimental and has not yet been run on a Windows machine in this repository. The NetEase client must publish a Windows SMTC session.

Windows build: [MiniPlayerWin-win-x64.zip](https://github.com/Kensh1n-Ch3n/MiniPlayer/releases/latest/download/MiniPlayerWin-win-x64.zip)

## ❓ FAQ

<details>
<summary><b>Why does the widget disappear after I click the album artwork?</b></summary>

This is intentional: the main Apple Music window and the widget are mutually exclusive on screen. Closing, minimizing, or quitting Music brings the widget back automatically.
</details>

<details>
<summary><b>Why are lyrics sometimes estimated?</b></summary>

Apple Music's scripting interface does not expose line timings. If there is no official TTML cache locally and neither LRCLIB nor NetEase has synced LRC, MiniPlayer can only estimate from plain text, and perfect zero-offset alignment is not guaranteed.
</details>

<details>
<summary><b>Why isn't it on the App Store?</b></summary>

This is a local utility without notarization or sandbox adaptation. Public distribution would require additional signing and review configuration.
</details>

## ☕ Support the Author

If MiniPlayer is useful to you, consider buying me a cup of tea. Your support keeps it going.

<p align="center">
  <img src="macos/docs/alipay-qr.jpg" alt="Alipay QR code" width="300">
</p>

<p align="center">
  <b>Open Alipay and scan the QR code</b><br>
  <sub>Buy Me a Coffee · 饮茶先啦 (*晨)</sub>
</p>

## 🙏 Credits

- [Apple SwiftUI `Glass` documentation](https://developer.apple.com/documentation/SwiftUI/Glass) and [awesome-liquid-glass](https://github.com/GetStream/awesome-liquid-glass): references for native Liquid Glass
- [LRCLIB](https://lrclib.net): open synced lyric data

## 📄 License

This project is released under the **MIT License**. See [LICENSE](LICENSE) for the full text.

---

<div align="center">
  <sub>Made for macOS · Apple Music & NetEase Cloud Music · Released under the MIT License</sub>
</div>
