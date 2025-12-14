//
//  OSSFileBrowserView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI
import AlibabaCloudOSS

// 文件浏览器内容 - 不包含工具栏
struct OSSFileBrowserContent: View {
    let bucket: BucketItem
    let config: OSSConfiguration
    let onFileCountUpdate: (Int, Int, Bool) -> Void

    @StateObject private var fileService: OSSFileService
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var uploadManager = UploadManager.shared
    @State private var selectedFiles: Set<String> = []
    @State private var showingCreateFolder = false
    @State private var folderName = ""
    @State private var showingDownloadProgress = false
    @State private var showingUploadProgress = false

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
                onCopyPresignedURL: handleCopyPresignedURL
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
        .alert("创建文件夹", isPresented: $showingCreateFolder) {
            TextField("文件夹名称", text: $folderName)
            Button("创建") {
                createFolder()
            }
            .disabled(folderName.isEmpty)
            Button("取消", role: .cancel) {}
        } message: {
            Text("请输入文件夹名称")
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
        .toolbar {
            // 左侧导航按钮
            ToolbarItemGroup(placement: .navigation) {
                Button(action: {
                    Task {
                        try? await fileService.goBack()
                    }
                }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!fileService.canGoBack || fileService.isLoading)
                .help("返回上级目录")

                Button(action: {
                    Task {
                        try? await fileService.goForward()
                    }
                }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!fileService.canGoForward || fileService.isLoading)
                .help("前进")
            }

            // 右侧操作按钮
            ToolbarItemGroup(placement: .automatic) {
                Button(action: {
                    Task {
                        try? await fileService.listFiles(at: fileService.currentPath)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .controlSize(.mini)
                }
                .disabled(fileService.isLoading)
                .help("刷新")

                Button(action: { showingCreateFolder = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .controlSize(.mini)
                }
                .disabled(fileService.isLoading)
                .help("新建文件夹")

                // 下载进度按钮
                Button(action: {
                    showingDownloadProgress = true
                }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 14))
                        .controlSize(.mini)
                        .overlay(
                            // 显示下载数量徽章
                            Group {
                                let activeCount = downloadManager.downloadTasks.filter { task in
                                    task.status == .downloading || task.status == .pending
                                }.count
                                if activeCount > 0 {
                                    Text("\(activeCount)")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                                }
                            }
                        )
                }
                .help("查看下载进度")

                // 上传进度按钮
                Button(action: {
                    showingUploadProgress = true
                }) {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 14))
                        .controlSize(.mini)
                        .overlay(
                            // 显示上传数量徽章
                            Group {
                                let activeCount = uploadManager.uploadTasks.filter { task in
                                    switch task.status {
                                    case .pending, .uploading:
                                        return true
                                    default:
                                        return false
                                    }
                                }.count
                                if activeCount > 0 {
                                    Text("\(activeCount)")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                                }
                            }
                        )
                }
                .help("查看上传进度")
            }
        }
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
            // TODO: 处理文件打开
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
                selectedFiles.remove(file.id.uuidString)
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
                DownloadManager.shared.downloadFolder(file, from: bucket.name, files: fileService.files)
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
        let endpoint = config.endpoint ?? "https://oss-\(config.region).aliyuncs.com"
        let url = "\(endpoint)/\(bucket.name)/\(file.key)"
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
        let ossConfig = Configuration.default()
            .withCredentialsProvider(StaticCredentialsProvider(
                accessKeyId: config.accessKeyId,
                accessKeySecret: config.accessKeySecret
            ))
            .withRegion(config.region)

        if let endpoint = config.endpoint {
            ossConfig.withEndpoint(endpoint)
        }

        let client = Client(ossConfig)

        do {
            let presignResult = try await client.presign(
                GetObjectRequest(
                    bucket: bucket.name,
                    key: file.key
                ),
                Date().addingTimeInterval(600) // 10分钟有效期
            )

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(presignResult.url, forType: .string)

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

    // MARK: - Create Folder
    private func createFolder() {
        guard !folderName.isEmpty else { return }

        Task {
            do {
                try await fileService.createDirectory(name: folderName)
            } catch {
                fileService.error = error
            }
        }
        folderName = ""
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
