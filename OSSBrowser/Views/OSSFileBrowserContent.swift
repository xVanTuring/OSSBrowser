//
//  OSSFileBrowserView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import AlibabaCloudOSS
import SwiftUI
import QuickLook

/// 上传前检测到同名项时的覆盖确认信息
private struct UploadConflict: Identifiable {
    let id = UUID()
    let urls: [URL]
    let conflictNames: [String]
}

// 文件浏览器内容 - 不包含工具栏
struct OSSFileBrowserContent: View {
    let bucket: BucketItem
    let config: OSSConfiguration
    /// 收藏导航时指定的初始路径；为 nil 时从 Bucket 根目录加载
    let initialPath: String?
    /// 收藏路径在导航后被发现已不存在时回调（用于提示用户删除该收藏）
    let onInvalidFavoritePath: ((String) -> Void)?
    let onFileCountUpdate: (Int, Int, Bool) -> Void
    /// 详情栏（inspector）显示状态，由父视图持有
    @Binding var inspectorPresented: Bool

    @StateObject private var fileService: OSSFileService
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var uploadManager = UploadManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @State private var selectedFiles: Set<String> = []
    @State private var isCreatingFolder = false
    @State private var showingDownloadProgress = false
    @State private var showingUploadProgress = false
    @State private var fileToPreview: OSSFile?
    @State private var previewURL: URL?
    @AppStorage(PreviewSettings.useQuickLookKey) private var useQuickLook: Bool = false
    @State private var searchText: String = ""
    @State private var toastText: String?
    @State private var uploadConflict: UploadConflict?

    init(
        bucket: BucketItem, config: OSSConfiguration,
        initialPath: String? = nil,
        onInvalidFavoritePath: ((String) -> Void)? = nil,
        inspectorPresented: Binding<Bool>,
        onFileCountUpdate: @escaping (Int, Int, Bool) -> Void
    ) {
        self.bucket = bucket
        self.config = config
        self.initialPath = initialPath
        self.onInvalidFavoritePath = onInvalidFavoritePath
        self._inspectorPresented = inspectorPresented
        self.onFileCountUpdate = onFileCountUpdate
        self._fileService = StateObject(
            wrappedValue: OSSFileService(config: config, bucketName: bucket.name))
    }

    var body: some View {
        VStack(spacing: 0) {
            FileListView(
                files: fileService.files,
                selectedFiles: $selectedFiles,
                isLoading: fileService.isLoading,
                hasMore: fileService.hasMore,
                isLoadingMore: fileService.isLoadingMore,
                onLoadMore: {
                    Task { try? await fileService.loadMoreFiles() }
                },
                onFileSelect: handleFileSelect,
                onFileDoubleClick: handleFileDoubleClick,
                onDownloadFile: handleDownloadFile,
                onDownloadFolder: handleDownloadFolder,
                onDeleteFile: handleDeleteFile,
                onDeleteMultiple: handleDeleteMultiple,
                onDownloadMultiple: handleDownloadMultiple,
                onDropFile: handleDropFile,
                onDropFolder: handleDropFolder,
                onCopyPath: handleCopyPath,
                onCopyURL: handleCopyURL,
                onCopyPresignedURL: handleCopyPresignedURL,
                onRenameFile: handleRenameFile,
                onPreview: handleFilePreview,
                isCreatingFolder: $isCreatingFolder,
                onCreateFolder: handleCreateFolder,
                onRefresh: handleRefresh,
                onUpload: handlePickAndUpload,
                searchQuery: fileService.currentSearchQuery,
                loadErrorMessage: fileService.loadError?.localizedDescription,
                onRetry: handleRetry,
                onClearSearch: { searchText = "" }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 底部路径导航栏
            PathNavigationView(
                bucketName: bucket.name,
                currentPath: fileService.currentPath,
                onPathClick: { path in
                    Task {
                        try? await fileService.listFiles(at: path)
                    }
                },
                isFavorite: favoritesManager.isFavorite(
                    configId: config.id, bucketName: bucket.name, path: fileService.currentPath),
                onToggleFavorite: {
                    favoritesManager.toggleFavorite(
                        configId: config.id, bucketName: bucket.name, path: fileService.currentPath)
                }
            )
        }
        .onAppear {
            Task {
                if let initialPath {
                    try? await fileService.listFiles(at: initialPath)
                    if !initialPath.isEmpty {
                        let exists = (try? await fileService.checkPathExists(initialPath)) ?? true
                        if !exists {
                            onInvalidFavoritePath?(initialPath)
                        }
                    }
                } else {
                    try? await fileService.listFiles()
                }
            }

            // 设置上传完成回调
            UploadManager.shared.onUploadComplete = {
                Task {
                    // 上传完成后刷新当前目录
                    try? await fileService.listFiles(at: fileService.currentPath)
                }
            }
        }
        .onChange(of: fileService.files.count) {
            onFileCountUpdate(fileService.files.count, selectedFiles.count, fileService.isLoading)
        }
        .onChange(of: selectedFiles.count) {
            onFileCountUpdate(fileService.files.count, selectedFiles.count, fileService.isLoading)
        }
        .onChange(of: fileService.isLoading) {
            onFileCountUpdate(fileService.files.count, selectedFiles.count, fileService.isLoading)
        }
        .alert("错误", isPresented: .constant(fileService.error != nil)) {
            Button("确定") {
                fileService.error = nil
            }
        } message: {
            if let error = fileService.error {
                Text(error.localizedDescription)
            }
        }
        .sheet(isPresented: $showingDownloadProgress) {
            DownloadProgressWindow()
        }
        .sheet(isPresented: $showingUploadProgress) {
            UploadProgressWindow()
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "搜索文件前缀")
        .onSubmit(of: .search) {
            Task {
                if searchText.isEmpty {
                    try? await fileService.listFiles(at: fileService.currentPath, addToHistory: false)
                } else {
                    try? await fileService.search(searchText)
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                Task {
                    try? await fileService.listFiles(at: fileService.currentPath, addToHistory: false)
                }
            }
        }
        .toolbar {
            // 左侧导航按钮
            ToolbarItemGroup(placement: .navigation) {
                Button(action: {
                    Task { try? await fileService.goBack() }
                }) {
                    Label("返回", systemImage: "chevron.left")
                }
                .disabled(!fileService.canGoBack || fileService.isLoading)
                .help("返回上级目录")

                Button(action: {
                    Task { try? await fileService.goForward() }
                }) {
                    Label("前进", systemImage: "chevron.right")
                }
                .disabled(!fileService.canGoForward || fileService.isLoading)
                .help("前进")
            }

            // 右侧操作按钮
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: handleRefresh) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(fileService.isLoading)
                .keyboardShortcut("r", modifiers: .command)
                .help("刷新 (⌘R)")

                Button(action: { isCreatingFolder = true }) {
                    Label("新建文件夹", systemImage: "folder.badge.plus")
                }
                .disabled(fileService.isLoading)
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .help("新建文件夹 (⇧⌘N)")

                // 下载进度按钮
                Button(action: { showingDownloadProgress = true }) {
                    Label {
                        Text("下载")
                    } icon: {
                        Image(systemName: "arrow.down.circle")
                            .overlay(alignment: .topTrailing) {
                                if activeDownloadCount > 0 { countBadge(activeDownloadCount) }
                            }
                    }
                }
                .help("查看下载进度")

                // 上传进度按钮
                Button(action: { showingUploadProgress = true }) {
                    Label {
                        Text("上传")
                    } icon: {
                        Image(systemName: "arrow.up.circle")
                            .overlay(alignment: .topTrailing) {
                                if activeUploadCount > 0 { countBadge(activeUploadCount) }
                            }
                    }
                }
                .help("查看上传进度")

                // 详情栏（inspector）切换 —— 放最右
                Button(action: { inspectorPresented.toggle() }) {
                    Label("详情栏", systemImage: "sidebar.right")
                }
                .help(inspectorPresented ? "隐藏详情栏" : "显示详情栏")
            }
        }
        // FilePreviewWindow sheet (用于传统预览模式)
        .sheet(item: $fileToPreview) { file in
            FilePreviewWindow(
                file: file,
                files: fileService.files.filter { !$0.isDirectory },
                bucketName: bucket.name,
                config: config
            )
        }
        // QuickLook 预览 (用于 QuickLook 模式)
        .quickLookPreview($previewURL)
        // 上传覆盖确认
        .confirmationDialog(
            "覆盖确认",
            isPresented: Binding(
                get: { uploadConflict != nil },
                set: { if !$0 { uploadConflict = nil } }
            ),
            presenting: uploadConflict
        ) { conflict in
            Button("覆盖上传", role: .destructive) {
                doUpload(conflict.urls)
            }
            Button("取消", role: .cancel) {}
        } message: { conflict in
            Text("当前目录已存在以下 \(conflict.conflictNames.count) 个同名项目，继续将覆盖：\n\n" + conflict.conflictNames.joined(separator: "\n"))
        }
        // 轻量操作反馈 toast
        .overlay(alignment: .bottom) {
            if let toastText {
                Text(toastText)
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.2)))
                    .shadow(radius: 10, y: 2)
                    .padding(.bottom, 56)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: toastText)
    }

    // MARK: - Toolbar Helpers
    private var activeDownloadCount: Int {
        downloadManager.downloadTasks.filter {
            $0.status == .downloading || $0.status == .pending
        }.count
    }

    private var activeUploadCount: Int {
        uploadManager.uploadTasks.filter { task in
            switch task.status {
            case .pending, .uploading: return true
            default: return false
            }
        }.count
    }

    @ViewBuilder
    private func countBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.red)
            .clipShape(Capsule())
            .offset(x: 6, y: -6)
    }

    // MARK: - Actions
    private func handleFileSelect(_ file: OSSFile) {
        // 处理文件选择
        print("Selected file: \(file.name)")
    }

    private func handleFileDoubleClick(_ file: OSSFile) {
        if file.isDirectory {
            Task {
                try? await fileService.changeDirectory(file)
            }
        } else {
            // 双击文件直接预览
            handleFilePreview(file)
        }
    }

    private func handleDownloadFile(_ file: OSSFile) {
        // 配置下载管理器
        DownloadManager.shared.configure(with: config)
        // 下载单个文件
        DownloadManager.shared.downloadFile(file, from: bucket.name)
    }

    private func handleDownloadFolder(_ folder: OSSFile) {
        // 配置下载管理器
        DownloadManager.shared.configure(with: config)
        // 下载整个文件夹
        DownloadManager.shared.downloadFolder(folder, from: bucket.name, files: fileService.files)
    }

    private func handleDeleteFile(_ file: OSSFile) {
        Task {
            do {
                try await fileService.deleteFile(file)
                // 刷新文件列表
                try? await fileService.listFiles(at: fileService.currentPath)
                // 清空选择
                selectedFiles.remove(file.id)
            } catch {
                fileService.error = error
            }
        }
    }

    private func handleDeleteMultiple(_ files: [OSSFile]) {
        Task {
            do {
                try await fileService.deleteFiles(files)
                // 刷新文件列表
                try? await fileService.listFiles(at: fileService.currentPath)
                // 清空选择
                selectedFiles.removeAll()
            } catch {
                fileService.error = error
            }
        }
    }

    private func handleDropFile(_ url: URL) {
        performUpload(urls: [url])
    }

    private func handleDropFolder(_ url: URL) {
        performUpload(urls: [url])
    }

    private func handleDownloadMultiple(_ files: [OSSFile]) {
        // 配置下载管理器
        DownloadManager.shared.configure(with: config)

        // 分别处理文件和文件夹
        for file in files {
            if file.isDirectory {
                // 下载文件夹
                DownloadManager.shared.downloadFolder(
                    file, from: bucket.name, files: fileService.files)
            } else {
                // 下载文件
                DownloadManager.shared.downloadFile(file, from: bucket.name)
            }
        }
    }

    private func handleCopyPath(_ file: OSSFile) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(file.key, forType: .string)
        showToast("已复制路径")
    }

    private func handleCopyURL(_ file: OSSFile) {
        // 构造正确的 OSS URL 格式
        let url: String
        if let customEndpoint = config.endpoint {
            // 如果有自定义 endpoint，直接使用不追加 bucket
            url = "\(customEndpoint)/\(file.key)"
        } else {
            // 使用默认的 OSS endpoint 格式：https://{bucket}.oss-{region}.aliyuncs.com/{file-key}
            url = "https://\(bucket.name).oss-\(config.region).aliyuncs.com/\(file.key)"
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url, forType: .string)
        showToast("已复制文件地址")
    }

    private func handleCopyPresignedURL(_ file: OSSFile) {
        Task {
            await generatePresignedURL(for: file)
        }
    }

    @MainActor
    private func generatePresignedURL(for file: OSSFile) async {
        do {
            let urlString = try await OSSPresigner.presignedURLString(
                bucket: bucket.name, key: file.key, config: config, expiresIn: 600)  // 10分钟有效期

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(urlString, forType: .string)

            showToast("已复制预签名地址（有效期 10 分钟）")
        } catch {
            fileService.error = error
        }
    }

    private func handleRenameFile(_ file: OSSFile, newName: String) {
        Task {
            do {
                try await fileService.renameFile(file, newName: newName)
            } catch {
                fileService.error = error
            }
        }
    }

    private func handleFilePreview(_ file: OSSFile) {
        if useQuickLook {
            // 使用 QuickLook 预览
            Task {
                do {
                    // 生成预签名URL，有效期1小时
                    let url = try await OSSPresigner.presignedURL(
                        bucket: bucket.name, key: file.key, config: config)
                    await MainActor.run {
                        previewURL = url
                    }
                } catch {
                    print("生成预签名URL失败: \(error)")
                    await MainActor.run {
                        fileService.error = error
                    }
                }
            }
        } else {
            // 使用原有的 FilePreviewWindow
            fileToPreview = file
        }
    }

    // MARK: - Create Folder / Refresh / Upload
    private func handleCreateFolder(_ name: String) {
        // 内联行已完成基础校验，这里直接创建
        isCreatingFolder = false
        Task {
            do {
                try await fileService.createDirectory(name: name)
            } catch {
                fileService.error = error
            }
        }
    }

    private func handleRefresh() {
        Task {
            try? await fileService.listFiles(at: fileService.currentPath, addToHistory: false)
        }
    }

    private func handlePickAndUpload() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "上传"
        panel.message = "选择要上传到当前目录的文件或文件夹"

        guard panel.runModal() == .OK else { return }
        performUpload(urls: panel.urls)
    }

    // MARK: - Upload with overwrite check

    private func performUpload(urls: [URL]) {
        guard !urls.isEmpty else { return }
        let existingNames = Set(fileService.files.map { $0.name })
        let conflictNames = urls.map { $0.lastPathComponent }.filter { existingNames.contains($0) }
        if conflictNames.isEmpty {
            doUpload(urls)
        } else {
            uploadConflict = UploadConflict(urls: urls, conflictNames: conflictNames)
        }
    }

    private func doUpload(_ urls: [URL]) {
        for url in urls {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                fileService.uploadFolder(url)
            } else {
                fileService.uploadFile(url)
            }
        }
    }

    // MARK: - Toast / Retry

    private func showToast(_ text: String) {
        toastText = text
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                if toastText == text { toastText = nil }
            }
        }
    }

    private func handleRetry() {
        Task {
            if fileService.currentSearchQuery.isEmpty {
                try? await fileService.listFiles(at: fileService.currentPath, addToHistory: false)
            } else {
                try? await fileService.search(fileService.currentSearchQuery)
            }
        }
    }
}

#Preview {
    OSSFileBrowserContent(
        bucket: BucketItem(
            name: "test-bucket",
            region: "cn-hangzhou",
            creationDate: Date(),
            storageClass: "Standard"
        ),
        config: OSSConfiguration(
            name: "Test Config",
            accessKeyId: "",
            accessKeySecret: "",
            region: "cn-hangzhou"
        ),
        inspectorPresented: .constant(true),
        onFileCountUpdate: { _, _, _ in }
    )
}
