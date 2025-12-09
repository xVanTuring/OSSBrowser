# OSS Browser 项目架构文档

## 项目概述
一个基于 SwiftUI 的 macOS 原生 OSS 文件管理应用，用于管理阿里云 OSS 存储服务。

## 功能需求

### 核心功能
- 多配置管理（使用 Keychain 安全存储）
- Bucket 浏览
- 文件/文件夹浏览（层级结构）
- 文件上传（支持分片上传）
- 文件下载
- 文件操作（删除、重命名、移动）
- 文件搜索（按文件名）
- 文件详情查看

### UI 结构
- 三栏布局：左侧边栏（桶列表）、中间（文件列表）、右侧（文件详情）
- 类 Finder 的列表视图
- 多窗口模式（每个配置一个窗口）

## 技术架构

### 1. 依赖管理
使用阿里云 OSS Swift SDK v2：
```swift
.package(url: "https://github.com/aliyun/alibabacloud-oss-swift-sdk-v2.git", from: "0.1.0-beta")
```

### 2. 模块设计

#### 配置管理模块 (Configuration)
- `OSSConfiguration`: 配置数据模型
- `ConfigurationManager`: 配置的增删改查
- `KeychainManager`: Keychain 存储管理
- `ConfigurationWindow`: 配置选择窗口

#### OSS 服务模块 (OSSService)
- `OSSClient`: 基于阿里云 SDK 的封装
- `BucketService`: Bucket 相关操作
- `ObjectService`: 文件对象相关操作
- `UploadManager`: 上传任务管理（分片上传）
- `DownloadManager`: 下载任务管理

#### 文件管理模块 (FileManager)
- `BucketItem`: Bucket 数据模型
- `OSSFile`: 文件数据模型
- `FileOperation`: 文件操作（删除、重命名、移动）

#### UI 模块 (Views)
- `MainWindow`: 主窗口（三栏布局）
- `SidebarView`: 左侧边栏（Bucket 列表）
- `FileListView`: 中间文件列表（虚拟化）
- `FileDetailView`: 右侧文件详情
- `UploadProgressView`: 上传进度视图
- `ContextMenu`: 右键菜单

### 3. 数据模型

```swift
// OSS 配置
struct OSSConfiguration {
    let id: UUID
    let name: String
    let accessKeyId: String
    let accessKeySecret: String
    let region: String
    let endpoint: String?
}

// Bucket 信息
struct BucketItem: Identifiable {
    let id: String
    let name: String
    let region: String
    let creationDate: Date
    let storageClass: String
}

// 文件信息
struct OSSFile: Identifiable {
    let id: String
    let key: String
    let size: Int64
    let lastModified: Date
    let eTag: String
    let storageClass: String
    let isDirectory: Bool
}
```

### 4. 关键技术实现

#### 分片上传
- 小文件（< 100MB）：直接上传
- 大文件（≥ 100MB）：使用 SDK 的分片上传功能
- 支持并发上传多个分片
- 显示上传进度
- 支持取消上传

#### 虚拟化列表
- 使用 `LazyVStack` 或 `Table` 实现大量文件的虚拟化显示
- 分页加载文件列表

#### 多窗口管理
- 每个配置对应一个主窗口
- 窗口标题显示配置名称
- 使用 `WindowGroup` 管理多个窗口

#### 右键菜单
- 删除（需要确认）
- 重命名
- 移动到...
- 下载
- 复制文件路径

## 项目结构

```
OSSBrowser/
├── App/
│   ├── OSSBrowserApp.swift
│   └── ContentView.swift
├── Configuration/
│   ├── Models/
│   │   └── OSSConfiguration.swift
│   ├── Managers/
│   │   ├── ConfigurationManager.swift
│   │   └── KeychainManager.swift
│   └── Views/
│       └── ConfigurationWindow.swift
├── OSSService/
│   ├── OSSClient.swift
│   ├── BucketService.swift
│   ├── ObjectService.swift
│   ├── UploadManager.swift
│   └── DownloadManager.swift
├── FileManager/
│   ├── Models/
│   │   ├── BucketItem.swift
│   │   └── OSSFile.swift
│   └── Operations/
│       └── FileOperation.swift
├── Views/
│   ├── MainWindow.swift
│   ├── SidebarView.swift
│   ├── FileListView.swift
│   ├── FileDetailView.swift
│   └── ProgressView.swift
├── Utilities/
│   ├── FileIconHelper.swift
│   └── DateFormatter+Extensions.swift
└── Resources/
    └── Assets.xcassets
```

## 开发计划

1. **第一阶段：基础架构**
   - 项目初始化
   - 依赖集成
   - 基础数据模型

2. **第二阶段：配置管理**
   - Keychain 存储
   - 配置 CRUD
   - 配置选择窗口

3. **第三阶段：OSS 服务集成**
   - SDK 封装
   - Bucket 列表
   - 文件列表

4. **第四阶段：UI 实现**
   - 主窗口三栏布局
   - 文件列表虚拟化
   - 文件详情面板

5. **第五阶段：文件操作**
   - 上传下载
   - 分片上传
   - 进度显示
   - 文件操作（CRUD）

6. **第六阶段：优化完善**
   - 搜索功能
   - 错误处理
   - 性能优化

## 注意事项

1. **安全**：AccessKey 必须使用 Keychain 存储，不能明文保存
2. **性能**：大量文件时使用虚拟化列表，避免内存问题
3. **用户体验**：操作反馈（进度条、状态提示）
4. **错误处理**：网络错误、权限错误等友好提示
5. **配置**：分片大小等配置可设置
6. **macOS 沙盒权限**：
   - 网络请求需要开启 "Outgoing Connections (Client)" 权限
   - 文件上传下载需要配置文件访问权限
   - 在 Xcode 项目设置中：Signing & Capabilities -> App Sandbox -> Outgoing Connections (Client)
   - 需要文件操作时还要添加：File Access -> Downloads/Downloads Folder/Selected Files

## 待确认事项

1. 是否需要支持断点续传（当前不考虑）
2. 是否需要支持文件预览功能
3. 是否需要支持批量操作
4. Bucket 存储使用量的获取方式（需要确认 API）