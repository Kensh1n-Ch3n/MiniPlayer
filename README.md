<div align="center">

<img src="docs/banner.png" alt="音乐小窗 · MiniPlayer" width="100%">

# 音乐小窗 · MiniPlayer

**给 macOS Apple Music 的悬浮播放器，加上刚刚好的桌面歌词和菜单栏歌词。**

<p>
  <a href="https://github.com/Kensh1n-Ch3n/MiniPlayer/releases/latest"><img alt="Release" src="https://img.shields.io/badge/Release-v1.1.4-blueviolet?style=flat-square"></a>
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift">
  <img alt="Liquid Glass" src="https://img.shields.io/badge/UI-Liquid%20Glass-8A2BE2?style=flat-square">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/License-MIT-green?style=flat-square"></a>
  <a href="https://github.com/Kensh1n-Ch3n/MiniPlayer"><img alt="GitHub" src="https://img.shields.io/badge/GitHub-MiniPlayer-181717?style=flat-square&logo=github"></a>
  <a href="#-支持作者"><img alt="Buy Me a Coffee" src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-支持作者-ffdd00?style=flat-square&logo=buymeacoffee&logoColor=black"></a>
</p>

<p>
  <a href="#-功能">功能</a> ·
  <a href="#-界面">界面</a> ·
  <a href="#-安装">安装</a> ·
  <a href="#-使用">使用</a> ·
  <a href="#-歌词与对齐">歌词与对齐</a> ·
  <a href="#-资源占用">资源占用</a> ·
  <a href="#-常见问题">FAQ</a> ·
  <a href="#-license">License</a> ·
  <a href="#-支持作者">支持作者</a>
</p>

</div>

---

## ✨ 功能

- **原生 Liquid Glass**：macOS 26+ 使用 SwiftUI 原生 `.glassEffect(.clear, in:)`，由系统完成折射、模糊和边缘高光；macOS 14–15 回退到自定义虚化。
- **迷你长条模式**：播放器右上角一键收起为 300×56 的胶囊长条，保留封面、歌曲名、上一首 / 播放 / 下一首、展开按钮和一条细进度线；点击封面会打开 Apple Music，悬停时封面会高亮并显示打开箭头。
- **完整播放控制**：收藏、上一首、播放 / 暂停、下一首；进度条支持点击和拖动跳转。
- **原生交互反馈**：播放/暂停图标缩放切换，上一首/下一首朝对应方向滑出再滑入；连续点击时控制命令串行执行，不会出现状态错乱。
- **点封面打开 Apple Music**：点击专辑封面会打开 / 唤起 Music，同时隐藏小组件。Music 窗口与小组件互斥，关闭 Music 窗口、最小化或退出后小组件自动回来。
- **单行桌面歌词**：只显示当前这一句，不显示上下句；窗口宽度会根据歌词长度动态调整，短句更窄、长句自动加宽，方便左右拖动；点击卡片右下角的歌词按钮即可开关。
- **菜单栏歌词**：菜单栏显示当前歌词，长句平滑横向滚动，滚完整句后停止，不循环；换句时上下滑动。按住 `⌘` 拖动歌词项可调整它在菜单栏中的位置。
- **直接拖动歌词**：鼠标移到桌面歌词文字上会变成手形，按住文字本身即可移动，松手自动保存。不需要菜单或额外图标。
- **歌词对齐**：优先读取 Apple Music 本地缓存的官方逐行 TTML，使用 Apple 自己的时间轴；默认偏置 0。
- **歌词回退**：没有官方缓存时依次尝试 LRCLIB 同步 LRC、网易云 LRC，最后才使用内嵌歌词 / 时间估算。
- **原文优先**：繁体中文自动转简体；英文、韩文、日文保留原文，不再被中文翻译覆盖。韩文歌显示韩文，不会整首变成中文。
- **边界约束**：播放器卡片和桌面歌词都被限制在屏幕可见区域内，拖不出屏幕。
- **低占用**：播放中开启桌面歌词约 **1.1% CPU**，常驻内存约 **40 MB**。

## 📸 界面

<p align="center">
  <b>Liquid Glass 完整播放器</b><br><br>
  <img src="docs/ui-full.png" alt="Liquid Glass 完整播放器" width="82%">
</p>

<p align="center">
  <b>单行桌面歌词</b><br><br>
  <img src="docs/ui-lyrics.png" alt="单行桌面歌词" width="100%">
</p>

<p align="center">
  <b>迷你长条模式</b><br><br>
  <img src="docs/ui-mini.png" alt="迷你长条模式" width="72%">
</p>

> 原生玻璃会实时采样组件背后的窗口内容。背后是照片或壁纸时会显示被虚化的颜色；背后是白色窗口时偏白，这是系统玻璃的真实行为。

## 🚀 安装

### 直接使用

1. 下载并解压 [MiniPlayer.zip](https://github.com/Kensh1n-Ch3n/MiniPlayer/releases/latest/download/MiniPlayer.zip)。
2. 把 `MiniPlayer.app` 拖进「应用程序」文件夹。
3. 双击打开。

首次启动时系统会弹出：

> 「MiniPlayer.app」想要控制「音乐.app」

请点 **允许**。如果误点「不允许」，可以在菜单栏音乐小窗里打开 **自动化权限设置…**，或手动前往：

`系统设置 → 隐私与安全性 → 自动化 → 音乐小窗 → 音乐`

### 系统要求

- macOS 14 或更新版本
- Apple Music
- 原生 Liquid Glass 需要 macOS 26+；旧系统会自动使用回退玻璃效果

## 🎮 使用

| 操作 | 方式 |
| --- | --- |
| 移动播放器 | 按住卡片顶部空白区域拖动 |
| 打开 Apple Music | 点击专辑封面；小组件会隐藏，关闭 Music 窗口后自动回来 |
| 显示 / 隐藏播放器 | 菜单栏音符图标，`⌘⇧M` |
| 收起为迷你模式 | 卡片右上角的收起按钮，或菜单栏 → 收起为迷你模式 |
| 展开完整播放器 | 长条右侧的展开按钮，或菜单栏 → 展开完整播放器 |
| 显示 / 隐藏桌面歌词 | 卡片右下角歌词按钮，`⌘⇧L` |
| 显示 / 隐藏菜单栏歌词 | 菜单栏菜单 → 在菜单栏显示歌词 |
| 调整菜单栏歌词位置 | 按住 `⌘` 拖动菜单栏歌词项 |
| 移动桌面歌词 | 直接按住歌词文字拖动 |
| 调整歌词时间 | 菜单栏 → 歌词设置 → 提前 / 延迟 0.2 秒 |
| 调整歌词字号 / 位置 | 菜单栏 → 歌词设置 |
| 请作者喝咖啡 | 菜单栏 → 请作者喝杯咖啡… |
| 退出 | 菜单栏 → 退出音乐小窗，`⌘Q` |

## 🎵 歌词与对齐

### 来源顺序

1. **Apple Music 官方 TTML 缓存**：Music 播放时会把官方逐行歌词缓存在本机，App 直接解析 Apple 的时间轴。这是默认的 0 偏置对齐来源。
2. **LRCLIB**：如果 Apple 没有缓存，使用 LRCLIB 的同步 LRC。
3. **网易云音乐 LRC**：LRCLIB 只有纯文本时使用。
4. **Apple Music 内嵌歌词 / 估算**：最后兜底；没有真实时间轴时不保证对齐。

歌词缓存目录：`~/Library/Caches/MiniPlayer/lyrics`

### 关于偏移

- 使用真实时间轴的歌，**偏置 0 即对齐**。
- 如果某个版本的音乐/歌词本身有时间差，可以在菜单栏微调 ±0.2 秒。
- 英文歌保留英文；韩文、日文等非拉丁原文才显示中文译文。

## ⚡ 资源占用

本机（Apple Silicon / macOS 27）用 `top` 实测：

| 状态 | 平均 CPU |
| --- | ---: |
| 播放中 + 桌面歌词显示 | **1.14%** |
| 播放中 + 桌面歌词隐藏 | **0.75%** |
| 暂停 | **0.64%** |

- 常驻内存约 **40 MB**
- 歌词刷新不是 10Hz 持续重绘，而是按下一句的时间点精确唤醒
- 均衡器使用 Core Animation，不持续占用主线程

## 🛠️ 从源码构建

要求 Xcode 15+、Swift 5.9+。

```bash
cd MiniPlayer
./scripts/build.sh
```

构建产物：

- `dist/MiniPlayer.app`
- `dist/MiniPlayer.zip`

App 会优先使用本机可用的 Apple Development 证书签名；没有证书时回退 ad-hoc 签名。项目依赖系统框架，无第三方运行时依赖。

## ❓ 常见问题

<details>
<summary><b>为什么点击专辑封面后小组件消失了？</b></summary>

这是设计行为：Apple Music 主窗口和小组件在屏幕上互斥。关闭 Music 窗口、最小化或退出 Music 后，小组件会自动回来。
</details>

<details>
<summary><b>为什么歌词有时候是估算的？</b></summary>

Apple Music 的脚本接口不暴露逐行时间轴；如果本机没有官方 TTML 缓存、LRCLIB 和网易云也没有同步 LRC，就只能按纯文本估算，此时无法保证 0 偏置完美对齐。
</details>

<details>
<summary><b>为什么没有上架 App Store？</b></summary>

本项目是本地自用工具，没有做公证和沙盒适配。正式分发需要额外的签名与审核配置。
</details>

## ☕ 支持作者

如果音乐小窗对你有帮助，欢迎请我喝杯茶。你的支持会让它继续更新。

<p align="center">
  <img src="docs/alipay-qr.jpg" alt="支付宝收款码" width="300">
</p>

<p align="center">
  <b>打开支付宝扫一扫</b><br>
  <sub>Buy Me a Coffee · 饮茶先啦 (*晨)</sub>
</p>

## 🙏 致谢

- [Apple SwiftUI `Glass` 文档](https://developer.apple.com/documentation/SwiftUI/Glass) 与 [awesome-liquid-glass](https://github.com/GetStream/awesome-liquid-glass)：原生 Liquid Glass 的参考示例
- [LRCLIB](https://lrclib.net)：开放同步歌词数据

## 📄 License

本项目使用 **MIT License**，完整协议见根目录的 [LICENSE](LICENSE) 文件。

---

<div align="center">
  <sub>Made for macOS · Apple Music only · Released under the MIT License</sub>
</div>
