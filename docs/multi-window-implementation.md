# OSS Browser 多窗口实现方案

## 概述

本文档描述了 OSS Browser 的多窗口实现方案，该方案使用 SwiftUI 的原生 API 实现了为每个 OSS 配置创建独立浏览窗口的功能。

## 技术方案

### 核心技术栈

- **SwiftUI 16+**: 使用 `WindowGroup(for:)` 和 `openWindow(value:)` API
- **SwiftUI Navigation**: 使用 `NavigationSplitView` 实现三列布局
- **Combine**: 用于响应式数据绑定
- **macOS Keychain**: 安全存储配置信息

### 架构设计

#### 1. 主应用结构 (OSSBrowserApp.swift)

```swift
@main
struct OSSBrowserApp: App {
    @StateObject private var configManager = ConfigurationManager()

    var body: some Scene {
        // 配置管理窗口
        WindowGroup("配置管理") {
            ConfigurationListView()
                .environmentObject(configManager)
        }

        // OSS 浏览器窗口 - 支持多个实例
        WindowGroup(for: OSSConfiguration.self) { $config in
            if let config = config {
                OSSBrowserContentView(config: config, ossService: OSSService())
                    .frame(minWidth: 900, minHeight: 600)
            } else {
                Text("请从配置管理窗口打开 OSS 浏览器")
                    .foregroundColor(.secondary)
                    .frame(minWidth: 900, minHeight: 600)
            }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
    }
}
```

#### 2. 配置管理视图 (ConfigurationListView.swift)

```swift
struct ConfigurationListView: View {
    @StateObject private var configManager = ConfigurationManager()
    @Environment(\.openWindow) private var openWindow
    @State private var selectedConfig: OSSConfiguration?

    // 双击打开 OSS 浏览器窗口
    private func openMainWindow() {
        if let config = selectedConfig {
            openWindow(value: config)
        }
    }
}
```

## 实现细节

### 1. 配置数据模型 (OSSConfiguration)

```swift
struct OSSConfiguration: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let accessKeyId: String
    let accessKeySecret: String
    let region: String
    let endpoint: String?
}
```

关键特性：
- **Identifiable**: 符合 SwiftUI 的列表要求
- **Hashable**: 可作为 WindowGroup 的键值
- **Codable**: 支持序列化存储

### 2. 窗口管理机制

使用 SwiftUI 16+ 的新特性：
- `WindowGroup(for:)`: 为特定类型创建窗口组
- `openWindow(value:)`: 通过环境值打开新窗口

### 3. 数据流

1. 配置管理窗口展示所有已保存的配置
2. 用户双击配置时，调用 `openWindow(value: config)`
3. SwiftUI 自动创建或显示对应的 OSS 浏览器窗口
4. 窗口之间完全独立，互不影响

## 用户体验

### 窗口管理
- 每个配置可以打开独立的浏览器窗口
- 窗口标题显示配置名称："配置名 - OSS Browser"
- 支持同时打开多个窗口
- 窗口大小自动保存和恢复

### 交互流程
1. 打开应用，显示配置管理窗口
2. 单击选择配置进行编辑
3. 双击配置打开对应的 OSS 浏览器窗口
4. 可以随时返回配置管理窗口添加或修改配置

## 安全考虑

- 使用 macOS Keychain 存储敏感信息（AccessKey ID/Secret）
- 配置信息在传输和存储时进行加密
- 支持删除不需要的配置

## 性能优化

- 使用 `@StateObject` 和 `@EnvironmentObject` 进行高效的状态管理
- 懒加载 OSS 连接，仅在打开浏览器窗口时建立连接
- 每个窗口使用独立的 OSSService 实例

## 扩展性

该方案具有良好的扩展性：
- 可以轻松添加更多窗口类型（如设置窗口、关于窗口）
- 支持窗口间的通信（通过全局状态管理器）
- 可以为不同类型的资源创建专门的浏览器窗口

## 故障排除

### 常见问题

1. **窗口无法打开**
   - 确保使用 macOS 13+ 和 SwiftUI 16+
   - 检查 OSSConfiguration 是否符合 Hashable 协议

2. **配置未保存**
   - 检查 Keychain 权限
   - 确保在编辑时保留了配置的 ID

3. **窗口标题不正确**
   - 确保在 WindowGroup 中正确设置窗口标题

## 总结

该多窗口实现方案充分利用了 SwiftUI 的现代特性，提供了：
- 简洁的代码结构
- 类型安全的窗口管理
- 流畅的用户体验
- 良好的可维护性和扩展性

这是目前 macOS 应用多窗口实现的最佳实践之一。