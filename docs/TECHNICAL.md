# Technical

## 架构

- `VideoHarborCore`：URL 正规化、平台识别、命令构建、元数据/进度解析、任务持久化。
- `VideoHarbor`：SwiftUI 界面、AppKit 窗口透明化、进程生命周期、壁纸与用户交互。
- `Resources/Tools`：可选捆绑 `yt-dlp`、`ffmpeg`、`ffprobe` 及其动态库。

## 命令安全

- 只用 `Process.executableURL + arguments`，不组装 shell 命令。
- 下载模板固定在用户选择的目录，禁止 yt-dlp 执行任意 `--exec`。
- 不向日志写入 Cookie；浏览器 Cookie 选项默认关闭，且仅传递浏览器名称。
- 仅在浏览器 Cookie 库被系统拒绝访问、复制或解密时，公开内容会自动以无 Cookie 模式重试；登录校验失败不会触发降级，避免掩盖授权要求。
- 抖音明确返回 `Fresh cookies ... are needed` 时，启动已安装 Chromium 浏览器的 headless 隔离资料目录，等待真实视频源出现并落盘验证 Cookie，再让 yt-dlp 重试；该目录位于 VideoHarbor 自身 Application Support，不读取用户日常浏览器 Profile。
- 不下载播放列表，每次仅处理一条视频。

## 下载策略

- 默认 MP4：从 `bestvideo+bestaudio/best` 中显式排除 `format_note=watermarked` 源，依赖 ffmpeg 合并/封装；只有带水印源时失败而不静默回退。
- 清晰度上限通过 format selector 实现，不通过二次转码降质。
- 输出名使用 `title [id].ext`，开启 Windows/macOS 安全文件名。
- 通过 `--progress-template` 输出 JSON 进度，通过 `--print after_move:` 取得最终路径。

## 系统要求

- 目标：macOS 26，Apple Silicon。
- 源码保留 macOS 14 回退材质，但 V1 发布物仅对 macOS 26 验收。
- Core 可由 Swift 5.9 / macOS 14 SDK 构建；包含 `glassEffect` 的完整 GUI 需要 macOS 26 SDK（Xcode 26 / Swift 6.2+）。
- App Sandbox 关闭，以允许读取用户选定的目录与浏览器 Cookie 数据。

## 工具链完整性

- 构建时扫描 `Resources/Tools` 内全部 Mach-O 文件，包括没有可执行位的 `.dylib`；保留通过严格校验的上游签名，只为无效或本地修改过的文件补充 ad-hoc 签名，然后逐个复验。
- App 外层签名完成后实际启动内置 `ffmpeg` 与 `ffprobe`；动态库签名失效会直接中止构建。
- 运行时只有在 yt-dlp、ffmpeg 与 JavaScript runtime 均能成功执行版本命令时才把工具链标记为可用。

## 抖音风控恢复

- 支持 Google Chrome、Microsoft Edge 与 Brave，按已安装顺序选择；不复用个人 Profile。
- 隔离 Profile 成功后保留 20 分钟作为解析与下载之间的短期缓存，避免连续重复启动浏览器；过期或被平台拒绝时强制刷新一次。
- 页面就绪门禁同时要求 `<video>` 与 `douyinvod.com`/`aweme/v1/play` 真实源标记，避免登录弹层中的假视频标签造成过早结束。
