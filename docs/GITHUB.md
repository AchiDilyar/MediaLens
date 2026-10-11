# 首次上传 GitHub 与发布 DMG

仓库地址：<https://github.com/AchiDilyar/MediaLens>。

源码提交到 Git，DMG 上传到 Release；用户通过 README 下载按钮获取安装包。

## 1. 准备仓库

如果还没有创建仓库，在 GitHub 新建 **MediaLens**，选择 Public。首次创建空仓库时，不勾选自动生成 README、License 或 .gitignore，因为本项目已包含这些文件。

本地项目根目录为你的 MediaLens 源码目录。终端进入该目录后：

```sh
# 仅在还没有初始化 Git 时执行
git init -b main

# 仅在还没有设置 origin 时执行
git remote add origin https://github.com/AchiDilyar/MediaLens.git

# 查看当前远端
git remote -v
```

如果本地已设置 origin，请确认它指向上述仓库，不要重复添加。

## 2. 登录 GitHub

已安装 GitHub CLI 时：

```sh
gh auth login
```

按提示选择 **GitHub.com → HTTPS → 使用浏览器登录**，并允许 Git 使用 GitHub 凭据。不要将 token 写进源码或 remote URL。

也可使用 GitHub Desktop：添加现有本地仓库，选择 Publish repository，确认仓库名为 MediaLens，公开发布时取消 Keep this code private。

## 3. 检查并上传源码

```sh
git status --short
git add .
git diff --cached --stat
git commit -m "初始版本：MediaLens 原生媒体信息查看器与通用 DMG 发布流程"
git push -u origin main
```

提交列表应包含 Swift 源码、最终图标 `Assets/AppIcon.png`、README、脚本、测试与 `.github/`。

不会提交：

- `Assets/AppIcon/`：本地 Icon Composer 设计工程与多余导出。
- `.build/`、`dist/`、`output/`：缓存、App、DMG、测试素材和旧压缩包。
- `.DS_Store`、IDE 状态、`.env`、日志。

若 commit 提示身份未设置，请在当前仓库设置 `user.name`，并从 GitHub Settings → Emails 获取你的提交邮箱后设置 `user.email`。不要将示例邮箱当成自己的地址。

如果 GitHub 仓库已经有历史提交，先检查并整合远端历史；不要用强制推送覆盖它。普通 push 被拒绝时，应先处理分支历史，而不是删除本地或远端内容。

## 4. 本地制作通用 DMG

```sh
swift run MediaLensChecks
bash scripts/smoke-test.sh
bash scripts/package-release.sh
```

输出只有一套公开安装附件：

- `dist/MediaLens.dmg`
- `dist/MediaLens.dmg.sha256`

App 和内置 ffprobe 都合并了 `arm64`、`x86_64`，兼容 macOS 14+。DMG 包含应用、Applications 快捷方式和安装背景。

## 5. 发布第一个版本

确认 `scripts/Info.plist` 版本为 `0.3.0`，源码已推送，且 `main` 的 Actions 检查通过后：

```sh
git tag -a v0.3.0 -m "MediaLens 0.3.0"
git push origin v0.3.0
```

GitHub 的 **Draft release** 工作流会：

1. 在 Apple Silicon 和 Intel 运行器分别执行原生检查。
2. 构建一份通用 DMG，验证签名、挂载、应用架构和安装布局。
3. 创建 **Release 草稿**，附上 DMG 和校验文件。

进入仓库 **Releases**，检查草稿附件、更新说明和签名状态。确认后点击 **Publish release**，选择正式版本并设为 latest。此时 README 下载按钮开始生效。

草稿工作流不会自动公开发行，也不会覆盖已经发布的 Release。如果不用 Actions，可在 GitHub 手动创建对应 tag 的 Release，上传本地 DMG 和校验文件。

第一次正式发布后，删除 README 中“首个 Release 尚待发布”的提示并正常提交。

## 下载链接为什么无需每次改版本

公开附件固定命名为 `MediaLens.dmg`：

```text
https://github.com/AchiDilyar/MediaLens/releases/latest/download/MediaLens.dmg
```

GitHub 会将它重定向到 latest 正式版本的同名附件。不要将附件改为带版本号或带架构的名字，否则按钮无法匹配。

## 后续版本

更新 Info.plist、CHANGELOG 和 `docs/release-notes.md`，推送源码，再推送匹配的版本标签（如 `v0.3.1`）。工作流会拒绝与 plist 版本不匹配的标签。

正式面向公众分发前，还应完成 Developer ID 签名和 Apple 公证，详见 [发布指南](RELEASING.md)。
