# 开发指南

## 环境

- macOS 14 或更高版本，Swift 5.9 或更高版本。
- Xcode 或 Command Line Tools；核心模块与独立检查不要求完整 Xcode。
- `ffmpeg` / `ffprobe` 用于完整解析与集成测试；`python3` 用于验证集成检查输出。
- Icon Composer 仅用于重新编辑和导出图标，普通构建使用已提交的 PNG。

## 模块

`MediaLensCore` 包含 `MediaReport`、字段分组和格式化、`ProbeParser`、`MediaInspector`。ffprobe 的 JSON 转换为统一报告；原生解析生成标准化 JSON。

`MediaLens` 包含 SwiftUI 窗口和 `LibraryModel`。`AppDelegate` 提供 Finder 文件服务、单窗口重开、中文精简菜单和独立设置窗口。服务通过 `Info.plist` 的 `NSServices` 声明，接收现代文件 URL 与兼容的文件路径数组。状态在主线程更新，导入按路径去重，后台串行解析。移除条目后，迟到的结果不会重新插入。

`MediaLensChecks` 是 `Tests/MediaLensCoreTests` 中的独立可执行检查目标。这里使用 `swift run MediaLensChecks`，而不是 `swift test`。

## 常用命令

```sh
swift build
swift run MediaLens
swift run MediaLensChecks
bash scripts/smoke-test.sh
bash scripts/build-app.sh
bash scripts/package-release.sh
```

集成脚本临时生成 MP4、带字幕和章节的 MKV、WAV 和 PNG，检查中文路径与无效输入。测试结束后删除临时素材。

## 构建输出

所有衍生产物位于被 Git 忽略的 `dist/`；Swift 缓存位于 `.build/`。`dist/AppIcon/` 保存中间 PNG、iconset 和 ICNS，`dist/MediaLens.app` 是可运行应用。源码里的 `Assets/` 仅保存正式资源。

`scripts/Info.plist` 定义版本、bundle identifier 和最低系统版本。当前是 Swift Package 项目，没有独立 `.xcodeproj`；完整 Xcode 中打开 `Package.swift` 可用于开发。

## 当前边界

- 完整应用内置独立 ffprobe；原生框架回退的格式覆盖范围较小。
- 没有 App Store 沙盒、持久媒体库或网络服务。
- 发布脚本生成单一构建架构的应用，不生成 universal binary。
- 单元和集成检查不替代实际拖放、系统外观与报告导出的界面验收。

## 文件预览与内置引擎

`MediaFileView.swift` 将 AppKit 文件交互嵌入 SwiftUI：Quick Look 异步缩略图、默认应用打开、文件 URL 剪贴板与 copy-only 拖动。切换文件会取消旧缩略图请求，并校验回调对应的文件。音频保持系统文件图标。

`build-engine.sh` 固定并校验官方 FFmpeg 源码，生成只依赖系统库的独立 ffprobe。`build-app.sh` 默认交叉编译 arm64 / x86_64，将 App 与引擎分别合并，再将许可、对应源码一起放入 Resources 并签名。设置 APP_ARCHS 为本机架构可加速开发。源码运行和完整应用的引擎查找方式见 README。

## 图标与 DMG

公开构建只读取 `Assets/AppIcon.png`。本地 Icon Composer 工程位于被忽略的 `Assets/AppIcon/`；修改图标后可运行本地 `export-icon.sh` 更新最终 PNG，克隆者不需要 Icon Composer。

`package-release.sh` 总是生成通用 DMG；`make-dmg.sh` 通过原生磁盘映像工具和隔离 Python 工具写入安装窗口元数据，不操作 Finder。`check-dmg.sh` 验证映像、应用与引擎的两种架构、签名、快捷方式与布局。
