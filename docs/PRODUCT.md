# Product

## 用户目标

用户将来自抖音、B 站、YouTube 或 TikTok 的分享文本粘贴到一个输入框，先看到可验证的标题、封面、作者、时长与平台，再将授权内容保存到本地。

## 核心流程

`SHARE LINK → RESOLVE → SOURCE STREAM → MERGE → LOCAL FILE`

1. 从完整分享文本中提取第一个 HTTPS 链接。
2. 识别平台并通过 yt-dlp 解析元数据。
3. 用户选择清晰度、封装和下载目录。
4. 下载并在需要时由 ffmpeg 合并音视频。
5. 任务进入历史，可打开文件或 Finder 位置。

## 视觉约束

界面与 WinHarbor 0.7.x 同源：氧化蓝、海玻璃青、信号琥珀色；New York/SF Pro/SF Mono 字体层级；隐藏标题栏、全透明窗口、macOS 26 `glassEffect(.clear)`、动态壁纸与弹性按钮。品牌图标采用适配 macOS 26 的全画布深海蓝黑底、粗体白色 V 主标、缺口内海玻璃蓝模糊光影，以及与 V 尖端保持扩大间隙的加粗短横杆；Finder、Dock 与应用侧栏统一使用同一套图标资源。提取首页只保留标题、说明与链接输入，移除重复的“支持的入口”平台卡片。
