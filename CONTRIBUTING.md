# Contributing to VideoHarbor

感谢你愿意改进 VideoHarbor。提交代码前，请确认改动符合以下边界：

- 不加入 DRM 绕过、会员权益规避、账号风控规避或画面水印移除功能。
- 不收集、上传或记录 Cookie、访问令牌、下载历史等用户数据。
- 不把 `Resources/Tools`、`.app`、下载视频或诊断目录提交到仓库。
- 新功能应配套测试，并同步更新相关文档。

## 本地开发

```bash
swift test
swift run VideoHarbor
```

生成包含离线工具链的应用前，先执行：

```bash
./scripts/bootstrap_tools.sh
./build.sh
```

## 提交 Pull Request

1. 从 `main` 创建主题分支。
2. 保持提交聚焦，说明用户可见变化和验证方式。
3. 确保 `swift test` 通过。
4. 涉及下载行为时，补充授权内容边界和失败路径测试。

提交贡献即表示你同意按本仓库的 MIT License 授权该贡献。
