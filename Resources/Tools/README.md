# Bundled tools

此目录在公开源码仓库中只保留本说明，不提交预编译二进制。

执行 `../../scripts/bootstrap_tools.sh` 可在 Apple Silicon Mac 上准备：

- yt-dlp 2026.07.04
- Node.js 24.16.0
- 本机 Homebrew FFmpeg/ffprobe 及其非系统动态库

生成的文件受各自上游许可证约束，详见 `../THIRD_PARTY_NOTICES.md` 和
`../Licenses/`。它们不会被 Git 跟踪。
