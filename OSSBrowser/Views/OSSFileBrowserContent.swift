//
//  OSSFileBrowserView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import AlibabaCloudOSS
import SwiftUI
import QuickLook

// 文件浏览器内容 - 不包含工具栏
struct OSSFileBrowserContent: View {
    let bucket: BucketItem
    let config: OSSConfiguration
    let onFileCountUpdate: (Int, Int, Bool) -> Void

    @StateObject private var fileService: OSSFileService
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var uploadManager = UploadManager.shared
    @State private var selectedFiles: Set<String> = []
    @State private var isCreatingFolder = false
    @State private var showingDownloadProgress = false
    @State private var showingUploadProgress = false
    @State private var fileToPreview: OSSFile?
    @State private var previewURL: URL?
    @AppStorage(PreviewSettings.useQuickLookKey) private var useQuickLook: Bool = false
    @State private var searchText: String = ""

    init(
        bucket: BucketItem, config: OSSConfiguration,
        onFileCountUpdate: @escaping (Int, Int, Bool) -> Void
    ) {
        self.bucket = bucket
        self.config = config
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
                onUpload: handlePickAndUpload
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
                }
            )
        }
        .onAppear {
            Task {
                try? await fileService.listFiles()
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
            }
        }
        // FilePreviewWindow sheet (用于传统预览模式)
        .sheet(item: $fileToPreview) { file in
            FilePreviewWindow(
                file: file,
                bucketName: bucket.name,
                config: config
            )
        }
        // QuickLook 预览 (用于 QuickLook 模式)
        .quickLookPreview($previewURL)
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
        fileService.uploadFile(url)
    }

    private func handleDropFolder(_ url: URL) {
        fileService.uploadFolder(url)
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

            // 显示提示
            let alert = NSAlert()
            alert.messageText = "预签名地址已复制"
            alert.informativeText = "有效期：10分钟"
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "生成预签名地址失败"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
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

        for url in panel.urls {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                fileService.uploadFolder(url)
            } else {
                fileService.uploadFile(url)
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
        onFileCountUpdate: { _, _, _ in }
    )
}
