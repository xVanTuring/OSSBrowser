---
name: run-app
description: 编译并启动 OSSBrowser（macOS SwiftUI 应用）。当需要 build、run、启动应用、或验证改动在真实 app 中生效时使用。
---

# 编译并启动 OSSBrowser

OSSBrowser 是一个基于 SwiftUI 的原生 macOS Xcode 应用。依赖通过 Swift Package Manager 自动拉取（阿里云 OSS Swift SDK v2、XMLCoder、swift-crypto、swift-asn1），无需手动安装。

## 关键事实

- **工程根**：`OSSBrowser/`（相对仓库根，`.xcodeproj` 与 `.git` 都在这里）
- **工程文件**：`OSSBrowser.xcodeproj`（非 workspace）
- **Scheme**：`OSSBrowser`
- **Configuration**：日常开发/运行用 `Debug`，发布用 `Release`
- **Bundle ID**：`tech.xvanturing.OSSBrowser`
- **部署目标**：macOS 26.1（用户有意为之，勿改回 13）

## 编译

在工程根 `OSSBrowser/` 目录执行：

```bash
xcodebuild -project OSSBrowser.xcodeproj -scheme OSSBrowser -configuration Debug build
```

成功时输出末尾会有 `** BUILD SUCCEEDED **`。日志很长，用 `2>&1 | tail -30` 只看结尾即可；出错时按 `error:` 关键字过滤定位。

首次构建会 resolve 并拉取 SPM 依赖，可能较慢；之后走增量。

## 启动

产物在 DerivedData 里，路径带哈希，**不要硬编码**。用 `-showBuildSettings` 动态取产物目录，再 `open`：

```bash
DIR=$(xcodebuild -project OSSBrowser.xcodeproj -scheme OSSBrowser -configuration Debug \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')
open "$DIR/OSSBrowser.app"
```

验证已启动：

```bash
ps aux | grep -i "OSSBrowser.app" | grep -v grep
```

## 一步到位（build + launch）

```bash
cd OSSBrowser
xcodebuild -project OSSBrowser.xcodeproj -scheme OSSBrowser -configuration Debug build 2>&1 | tail -5 \
 && DIR=$(xcodebuild -project OSSBrowser.xcodeproj -scheme OSSBrowser -configuration Debug \
      -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}') \
 && open "$DIR/OSSBrowser.app"
```

## 只检测编译错误（不产出可运行 app，更快）

改代码后按项目约定需要检测编译错误，可用 `build` 或更轻的：

```bash
xcodebuild -project OSSBrowser.xcodeproj -scheme OSSBrowser -configuration Debug build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

## 备注

- 代码签名走本地开发身份（Apple Development），无需额外配置即可本地运行。
- 发布流程（Archive → Developer ID 签名 → 公证 → DMG → GitHub Release）见 `scripts/release.sh`，与本地 run 无关。
