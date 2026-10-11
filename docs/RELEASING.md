# 发布指南

## 提交范围

Git 中只保留可复现构建所需的源码、最终 PNG 图标、文档、测试和脚本。Icon Composer 工程与设计导出留在本地，已加入 .gitignore。App、DMG、旧 ZIP、引擎二进制与缓存都在忽略范围内。

首次上传步骤见 [GitHub 上手指南](GITHUB.md)。

## 通用安装包

```sh
swift run MediaLensChecks
bash scripts/smoke-test.sh
bash scripts/package-release.sh
```

发布脚本强制 Release 构建，交叉编译 `arm64` 和 `x86_64`，分别合并 Swift App 与独立 ffprobe。两种架构都以 macOS 14 为最低系统版本。

`MediaLens.dmg` 包含应用和 `/Applications` 快捷方式。安装窗口的背景与图标位置由文件元数据生成，打包脚本不会操作 Finder。制作 DMG 需要 Python 3.9+，依赖固定版本并安装在 `.build/dmg-tools/`。

产物固定为 `dist/MediaLens.dmg` 和 `dist/MediaLens.dmg.sha256`，便于 README 使用 GitHub latest 下载地址。更改架构、签名或公证后应重新生成并验证安装包。

## 发布前检查

1. 更新 `scripts/Info.plist` 的版本与 build number，更新 CHANGELOG 和 release-notes。
2. 运行核心、媒体、内置引擎和 DMG 检查。
3. 人工验收浅色 / 深色、导入、缩略图、拖出复制、快速查看、搜索与报告导出。
4. 安装到 Applications，验收 Finder 服务冷启动、多文件与关闭窗口后重新打开。
5. 验证 Intel 与 Apple Silicon 原生运行；交叉编译或 lipo 检查不能代替真实运行。
6. 确认包内附独立 ffprobe 的完整对应源码、许可和构建参数，不含测试素材或个人报告。
7. 确认本次实际签名 / 公证状态，保持下载页和 Release 说明一致。

## 签名和公证

未指定身份时，构建脚本使用 ad-hoc 签名，尚未进行 Apple 公证。Gatekeeper 可能拦截网上下载的包。不能将此产物描述为已公证安装包。

具有自己的 Developer ID Application 证书时：

```sh
SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' bash scripts/package-release.sh
```

脚本会对引擎、App 和 DMG 使用提供的身份签名，App 和引擎启用 hardened runtime 与时间戳。你需提前把真实证书安装到钥匙串；仓库不保存证书、密码或 Apple 凭据。

使用已配置的 notarytool 钥匙串 profile：

```sh
xcrun notarytool submit dist/MediaLens.dmg --keychain-profile MediaLens --wait
# 只有 notarization 返回 Accepted 后才执行：
xcrun stapler staple dist/MediaLens.dmg
xcrun stapler validate dist/MediaLens.dmg
(cd dist && shasum -a 256 MediaLens.dmg > MediaLens.dmg.sha256)
bash scripts/check-dmg.sh
spctl --assess --type open --context context:primary-signature --verbose dist/MediaLens.dmg
```

公证后 DMG 的摘要会变化，所以必须重新生成校验文件。实际成功后再修改 README 与 release-notes 的签名状态，使用该包替换 Release 草稿中的附件。当前 GitHub 自动构建没有证书秘密配置，因此仍生成 ad-hoc 草稿包。

## GitHub Actions 与 Release

- `build.yml`：main / PR / 手动运行时验证；Apple Silicon 与 Intel 分别执行原生解析检查，Apple Silicon 任务额外制作通用 DMG 并上传 artifact。
- `release.yml`：推送 `v*` 标签时复用验证流程，核对 tag 与 plist 版本，创建附带 DMG 和校验文件的 Release 草稿。
- 草稿需维护者检查后手动发布；已公开版本不会被 rerun 覆盖。
- latest 必须是正式发行版，并包含固定名称 `MediaLens.dmg`，README 下载按钮才能匹配。

每个 GitHub Release 保留一个通用 DMG 与其 SHA-256 文件，不再按架构发布两个 ZIP。

FFmpeg 许可、完整对应源码和构建参数须随每个应用包一起分发，见 [第三方组件](THIRD-PARTY.md)。
