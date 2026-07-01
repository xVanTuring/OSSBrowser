# OSSBrowser

一个基于 SwiftUI 的 macOS 原生 阿里云 OSS(对象存储)文件管理应用。

## 功能

- 多配置管理(AccessKey 使用 **Keychain** 安全存储,不落盘明文)
- Bucket 浏览
- 文件 / 文件夹层级浏览、搜索、分页
- 文件上传(分片)、下载(带进度)
- 文件操作:删除、重命名、移动
- 文件详情与预览
- 多窗口(每个配置一个窗口)

## 构建

依赖通过 Swift Package Manager 自动拉取(阿里云 OSS Swift SDK v2 等),clone 后直接用 Xcode 打开即可:

```bash
git clone https://github.com/xVanTuring/OSSBrowser.git
cd OSSBrowser
open OSSBrowser.xcodeproj   # 用 Xcode 打开后直接 Build/Run
```

命令行构建:

```bash
xcodebuild -project OSSBrowser.xcodeproj -scheme OSSBrowser -configuration Release build
```

## 发布(维护者)

见 [`scripts/release.sh`](scripts/release.sh):自动完成 版本号递增 → Archive → Developer ID 签名 → 公证(notarize)→ staple → 生成 zip + DMG → 发布 GitHub Release。

```bash
./scripts/release.sh 1.0.0                 # 正式发布
./scripts/release.sh 1.0.0 --dry-run       # 只递增版本 + 验证构建,不推送/不发布
./scripts/release.sh 1.0.0 --notes-file NOTES.md
```

App 图标源文件为 [`design/AppIcon.svg`](design/AppIcon.svg),改完后运行 [`scripts/make-icon.sh`](scripts/make-icon.sh) 重新生成图标集(需要 `brew install librsvg`)。

## 许可

本项目采用 **GNU General Public License v3.0** 协议,详见 [LICENSE](LICENSE)。
