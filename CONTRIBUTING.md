# 贡献指南

欢迎提交可复现的错误报告、界面改进和解析器修复。开始前请阅读 [开发指南](docs/DEVELOPMENT.md)。

## 提交问题

请说明 macOS 版本、硬件架构、MediaLens 版本、实际解析引擎，以及最小复现步骤。报告里可能含有完整文件路径或媒体标签；分享前请移除个人信息。优先提供自己生成的测试素材。

## 提交代码

1. Fork 仓库，在独立分支中修改。
2. 保持改动范围清楚，解析逻辑放在 `MediaLensCore`，界面与会话状态放在 `MediaLens`。
3. 修复解析行为时添加能覆盖问题的核心检查；无需为简单外观调整添加重复测试。
4. 执行核心检查、媒体集成检查和应用构建，并在 PR 中说明结果。界面调整请附实际截图。

```sh
swift run MediaLensChecks
bash scripts/smoke-test.sh
bash scripts/build-app.sh
```

不提交 `.build/`、`dist/`、个人媒体、原始报告、临时设计稿或本机设置。图标修改只提交最终资源 `Assets/AppIcon.png`；设计工程留在本地，不将多余导出加入 PR。构建方式见 [开发指南](docs/DEVELOPMENT.md)。

贡献将按本项目 MIT License 分发。
