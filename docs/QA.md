# QA

## 自动化

- URL：完整分享文本、短链、带中文标点、非 URL 文本。
- 平台：`douyin.com`、`bilibili.com`/`b23.tv`、`youtube.com`/`youtu.be`、`tiktok.com`。
- 命令：禁播放列表、输出目录、格式、清晰度、Cookie 和 ffmpeg 位置。
- 进度：JSON 百分比、速度、ETA、最终路径、非法行。
- 持久化：设置与任务历史 JSON 往返。

## 实机验收

- 窗口真透明，标题栏、拖动区、三主题和壁纸行为与 WinHarbor 一致。
- 粘贴链接后可解析预览，失败时显示可理解诊断。
- 下载期间进度持续更新，取消不留下假完成记录。
- 完成后文件可由 QuickTime 或 ffprobe 读取，音视频流存在。
- 全新复制的 `.app` 不依赖 `/opt/homebrew`，签名严格校验通过。
- 选择 Safari Cookie 且系统拒绝 Cookie 库访问时，公开 YouTube/B站链接自动以无 Cookie 模式重试成功；登录内容不误降级。
- `Resources/Tools` 内所有 Mach-O（含 `.dylib`）逐个通过严格签名校验，内置 ffmpeg/ffprobe 可从成品 App 与重新解压的 App 中启动。
- 抖音返回新鲜 Cookie 要求时，以应用专属 Chromium 隔离 Profile 自动恢复；必须用用户实际分享链接完成元数据与完整 MP4 下载，并由 ffprobe 验证音视频流、分辨率与时长。

## 平台矩阵

| 平台 | 公开链接解析 | 原始源流下载 | Cookie 可选 | 备注 |
|---|---:|---:|---:|---|
| 抖音 | 必验 | 必验 | 是 | 短链与风控可能变动 |
| 哔哩哔哩 | 必验 | 必验 | 是 | 高画质可需登录 |
| YouTube | 必验 | 必验 | 是 | 可需 JS runtime/PO Token |
| TikTok | 必验 | 必验 | 是 | 地区与反爬差异 |
