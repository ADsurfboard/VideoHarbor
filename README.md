# VideoHarbor

<p align="center">
  <img src="Resources/AppIcon.png" width="112" alt="VideoHarbor icon">
</p>

VideoHarbor 是一款开源的原生 macOS 视频保存工具。粘贴抖音、哔哩哔哩、
YouTube 或 TikTok 分享链接/分享文本，即可预览视频信息，并把你拥有或获授权的
公开源流保存到本地。

VideoHarbor is an open-source native macOS utility for inspecting and saving
video streams that you own or are authorized to download.

## 功能

- 分享文本 URL 提取与四平台识别。
- 标题、封面、作者、时长、分辨率和大小预览。
- 4K / 1080p / 720p / 最佳质量与 MP4 / MKV 选择。
- 多任务进度、取消、历史记录和 Finder 定位。
- 可选浏览器 Cookie，以及抖音新鲜验证信息的隔离 Chromium 会话恢复。
- 原生 SwiftUI 透明界面、三套主题及静态/动态壁纸。
- 可构建为带本地 yt-dlp、Node.js、FFmpeg/ffprobe 的离线 `.app`。

## 使用边界

- 仅下载你拥有或获得授权的视频，并遵守平台条款及当地法律。
- “原始源流”不代表所有链接都没有平台标记。
- VideoHarbor 不绕过 DRM、会员权限或账号风控，不擦除、裁切或重绘水印。
- 登录、会员、地区限制或临时风控内容可能无法下载。
- 默认不读取 Cookie；启用后只把所选浏览器名称交给本机 yt-dlp，应用不导出、
  上传或写入日志。
- 抖音需要新鲜验证信息时，可使用已安装的 Chrome、Edge 或 Brave 创建应用专属
  隔离资料目录；不会读取个人浏览器 Profile。

## 系统要求

- Core 开发与测试：macOS 14 或更高版本、Swift 5.9 或更高版本。
- 完整 GUI 构建：带 macOS 26 SDK 的 Xcode 26 / Swift 6.2 或更高版本。
- 当前发布构建：Apple Silicon；运行目标保留 macOS 14 回退材质，最终界面在
  macOS 26 验收。
- 完整离线包工具链：Homebrew FFmpeg，以及可访问 yt-dlp/Node.js 官方发布站点。

## 从源码运行

开发模式会优先寻找 `Resources/Tools`，随后寻找 Homebrew 安装的 `yt-dlp`、
`ffmpeg` 和 Node.js/Deno：

```bash
brew install yt-dlp ffmpeg node
./scripts/doctor.sh
./test.sh
./run.sh
```

`run.sh` 直接调用当前 Xcode/Command Line Tools 的 `swiftc`，不依赖本机
`PackageDescription` 动态库；因此即使 `swift run` 因 SwiftPM 组件版本不匹配而
无法载入 manifest，开发版仍可正常编译和启动。只验证完整 GUI 编译而不启动窗口，
可运行 `./run.sh --check`。

## 构建独立应用

公开仓库不会提交约 151 MB 的第三方预编译工具。以下脚本会校验官方发行文件、
复制本机 Homebrew FFmpeg 及其动态库，然后生成经过 ad-hoc 签名的应用：

```bash
./scripts/bootstrap_tools.sh
./scripts/doctor.sh --release
./build.sh
open VideoHarbor.app
```

`bootstrap_tools.sh` 要求至少 1 GiB 可用空间。它通过带超时和低速保护的官方接口
下载、校验并在临时目录组装工具链；只有全部工具能启动时才替换旧工具，因此网络
中断不会留下半套文件。`build.sh` 同样先在临时目录完成编译、签名和 8 项 Core
回归，再以可回滚方式替换旧应用，不会累积历史构建副本。生成的
`VideoHarbor.app` 与 `Resources/Tools` 都被 `.gitignore` 排除。

若命令报错，先运行 `./scripts/doctor.sh`。Core 开发缺少内置工具只会给出警告；
发布构建请使用 `--release`，任何缺失项都会明确列出。

维护者在官方站点速度异常时，也可通过 `YT_DLP_SOURCE` / `NODE_SOURCE` 指向本机
已有的同版本二进制，并分别提供 `YT_DLP_SHA256` / `NODE_SHA256`。脚本拒绝未声明
哈希或哈希不匹配的本地文件；这只复用经过明确校验的输入，不会静默信任缓存。

## 项目结构

```text
Sources/VideoHarborCore  链接、命令、模型与输出解析
Sources/VideoHarbor      SwiftUI 界面、任务和本地进程管理
Tests                    Core 单元与独立回归测试
Resources                图标、Info.plist 与第三方许可
scripts                  离线工具链准备脚本
docs                     产品、技术、路线图与验收说明
```

## 隐私与安全

VideoHarbor 没有中转服务器；视频链接只发送给对应平台，下载记录和设置保存在
本机。安全问题请参阅 [SECURITY.md](SECURITY.md)，贡献说明请参阅
[CONTRIBUTING.md](CONTRIBUTING.md)。

## 第三方组件与许可

VideoHarbor 源码使用 [MIT License](LICENSE)。yt-dlp、Node.js、FFmpeg 及其依赖
继续使用各自许可证；版本、源码和许可说明见
[Resources/THIRD_PARTY_NOTICES.md](Resources/THIRD_PARTY_NOTICES.md)。
