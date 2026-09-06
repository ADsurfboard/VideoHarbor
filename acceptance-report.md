# VideoHarbor 1.0.7 验收报告

日期：2026-09-06<br>
平台：macOS 26.5.2 / Apple Silicon<br>
应用：VideoHarbor 1.0.7 (build 8)

## 交付结论

1.0.7 修复了公开源码在干净目录无法构建、弱网下工具下载长期无响应、失败后残留半成品，以及重复构建持续堆积旧 App 的问题。工具准备与 App 构建现均先在临时区完整校验，再整体替换；失败会恢复旧版本。

1.0.6 的抖音恢复逻辑保持不变：现场复现确认 yt-dlp 2026.07.04 对已脱敏的真实短链返回 `Fresh cookies (not necessarily logged in) are needed`；Safari Cookie 又被 macOS 阻止读取，普通无 Cookie 回退无法解决这一站点风控要求。

新版在且仅在抖音返回新鲜 Cookie 要求时，使用已安装的 Chrome、Edge 或 Brave 建立 VideoHarbor 专属隔离 Profile，等待页面出现真实抖音视频源后再让 yt-dlp 重试。隔离 Profile 不读取用户个人浏览器资料，成功后短期复用于解析和下载，失效时强制刷新一次。

## 用户实际链接验收

| 项目 | 结果 | 证据 |
|---|---|---|
| 分享文本识别 | 通过 | 从完整中文分享文案提取已脱敏的抖音短链 |
| 原故障复现 | 通过 | 无 Cookie返回 `Fresh cookies ... are needed`；Safari 返回 `Operation not permitted` |
| 隔离浏览器恢复 | 通过 | Chrome 独立 Profile 生成验证信息，不读取个人 Chrome Profile |
| 完整 VideoEngine 解析 | 通过 | 保留用户 `cookieBrowser: safari` 设置，得到 ID `7673453423597079823`、原始标题、88 秒时长 |
| 完整 VideoEngine 下载 | 通过 | 同一分享链接下载完成，最终文件 8,502,608 字节 |
| macOS 图形界面解析 | 通过 | 从提取页解析第二条已脱敏真实短链，正确显示标题、作者、10 秒时长、720×1280 与 1.2 MB |
| 无水印源筛选 | 通过 | 选中 yt-dlp 标记为 `Playback video` 的源；显式排除 `watermarked` 格式 |
| 媒体可读性 | 通过 | ffprobe：88.97 秒、720×1280 HEVC 视频、AAC 音频 |

## 回归与打包验收

| 项目 | 结果 |
|---|---|
| Cookie 权限错误与普通登录错误隔离 | 通过 |
| 抖音 Fresh Cookie 错误识别 | 通过 |
| Core 测试 | 8/8 通过 |
| YouTube/B站公开链接回退 | 通过，无回归 |
| 内置 yt-dlp/Node/ffmpeg/ffprobe | 通过 |
| Tools 内全部 Mach-O 严格签名 | 21/21 通过 |
| App 外层严格签名 | 通过 |
| 最终 ZIP 全新解压、版本与工具启动 | 通过 |
| WinHarbor 同源透明 UI、最终 V 图标 | 保持不变 |
| “支持的入口”UI | 保持删除 |

## 已知边界

- 首次遇到抖音新鲜 Cookie 风控时，隔离浏览器会话通常需要约 20–50 秒；随后解析与下载可复用短期 Profile。
- 自动恢复需要已安装 Google Chrome、Microsoft Edge 或 Brave；若均不存在，应用会给出明确提示。
- TikTok、YouTube、B站仍可能受登录、地区、PO Token、会员或平台临时风控影响。
- 应用只下载平台公开提供的源流，不绕过 DRM，也不裁切、模糊或 AI 擦除画面水印。
- 交付物使用本地 ad-hoc 签名，未使用 Apple Developer ID 公证。

## 2026-08-26 开源验收

| 项目 | 结果 |
|---|---|
| Git 边界 | 通过；项目使用独立 `.git`，不再继承用户主目录的其他仓库 |
| 开源许可 | VideoHarbor 源码使用 MIT License；第三方组件保持各自许可证 |
| 公开清单 | 通过；不包含 `Resources/Tools` 二进制、`VideoHarbor.app`、`work`、`.build` 或 `.DS_Store` |
| 隐私与凭据扫描 | 通过；没有密钥、令牌、真实 Cookie、用户下载历史或个人绝对路径 |
| 可复现准备 | 通过；`scripts/bootstrap_tools.sh` 校验 yt-dlp 与 Node 官方发行文件，并调用 FFmpeg 动态库归档脚本 |
| Core 回归 | 8/8 通过 |
| 完整 App 构建 | 通过；版本 1.0.6 (7) |
| 成品工具链 | yt-dlp 2026.07.04、Node 24.16.0、FFmpeg/ffprobe 8.1.2 均可启动 |
| 代码签名 | 成品 App 通过 `codesign --verify --deep --strict` |

本机 Command Line Tools 的 Swift 6.3.3 编译器与 `PackageDescription` 动态库
存在链接版本不一致，因此本机 `swift test` 无法载入任何 SwiftPM manifest；这与
源码编译无关。项目自带的直接 `swiftc` 测试与完整构建均通过，公开仓库另由
GitHub Actions 的干净 macOS 14 环境构建 `VideoHarborCore` 并执行 8 项回归；
完整 GUI 因使用 macOS 26 `glassEffect`，由 Xcode 26 工具链验收。

## 2026-09-06 开源修复验收

| 项目 | 结果 |
|---|---|
| 干净目录构建 | 通过；`build.sh` 会先创建 `work`，不再因 `mktemp` 目标不存在而失败 |
| 弱网与中断 | 通过；官方请求包含连接、低速与总时长上限，中断后临时文件清零，旧工具不变 |
| 本地复用 | 通过；只有显式提供 64 位 SHA-256 且哈希匹配的同版本工具才允许复用 |
| 工具链事务 | 通过；错误哈希被拒绝，成功路径组装 19 个 FFmpeg 文件并整体替换 |
| 构建事务 | 通过；新 App 完成签名、工具启动与 Core 回归后才替换旧 App，失败可恢复 |
| 源码自检 | `scripts/doctor.sh`：0 个错误；Core 8/8；全部 shell 语法与 Info.plist 校验通过 |
