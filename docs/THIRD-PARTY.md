# 第三方组件

MediaLens 的 Swift 源码和自绘图标使用 MIT。应用内的检测引擎是独立进程 `ffprobe`，属于 FFmpeg 项目，保留自己的版权与许可。

## FFmpeg 8.0.1

- 上游：https://ffmpeg.org/
- 官方源码：https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz
- SHA-256：`05ee0b03119b45c0bdb4df654b96802e909e0a752f72e4fe3794f487229e5a41`
- 本项目构建未修改上游源码，禁用 GPL、nonfree、version3 和外部依赖自动检测（显式启用 macOS 系统 zlib，供 PNG 与压缩容器解析使用），生成 LGPL 2.1 或后续版本的独立 ffprobe。
- 禁用网络、编码器、封装输出和 ffmpeg / ffplay 程序；保留媒体探测需要的解封装器、解析器和解码器。
- FFmpeg 的静态库链接进独立 ffprobe 程序，未链接进 MediaLens 的 Swift 可执行文件。用户可在设置中指定替代 ffprobe。

每个应用包的 `Contents/Resources/ThirdParty/FFmpeg/` 包含：

| 文件 | 内容 |
| --- | --- |
| `COPYING.LGPLv2.1` | 完整 LGPL 许可 |
| `LICENSE.md` | 上游许可说明 |
| `ffmpeg-8.0.1.tar.xz` | 对应二进制的完整原始源码 |
| `build-engine.sh` | 本项目的构建脚本与全部配置参数 |
| `BUILD-INFO.txt` | 实际构建版本与配置 |

二进制位于 `Contents/Resources/bin/ffprobe`。源码归档随同应用压缩包分发，无需另外联系作者索取。重新构建的方法是在 MediaLens 项目根目录执行 `bash scripts/build-engine.sh`；首次构建会下载官方源码并校验摘要。通过 `ENGINE_ARCH=arm64` 或 `ENGINE_ARCH=x86_64` 指定目标；默认使用本机架构。构建脚本变化时缓存自动失效，删除 `dist/Engine/<arch>/ffprobe` 也可强制重编译。发布脚本将两个引擎合并成通用二进制，BUILD-INFO 保存两种配置。

发布者应同时保留以上材料与本说明。更新引擎时，必须一起更新版本、源码摘要、许可文件和对应源码；不能只替换二进制。

FFmpeg 分发说明：https://ffmpeg.org/legal.html

## DMG 构建工具

DMG 打包使用固定版本的 `ds_store`（MIT）与 `mac_alias`（MIT），仅在 `.build/dmg-tools/` 的隔离环境中使用，不作为 App 运行依赖，也不分发其程序代码。依赖列表在 `scripts/dmg-requirements.txt`，上游分别为 https://github.com/al45tair/ds_store 和 https://github.com/al45tair/mac_alias 。
