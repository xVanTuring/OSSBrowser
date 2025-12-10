//
//  OSSFileBrowserView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI

// 文件浏览器内容 - 不包含工具栏
struct OSSFileBrowserContent: View {
    let bucket: BucketItem
    let config: OSSConfiguration
    let onFileCountUpdate: (Int, Int, Bool) -> Void

    @StateObject private var fileService: OSSFileService
    @State private var selectedFiles: Set<String> = []
    @State private var showingCreateFolder = false
    @State private var folderName = ""

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
        FileListView(
            files: fileService.files,
            selectedFiles: $selectedFiles,
            isLoading: fileService.isLoading,
            onFileSelect: handleFileSelect,
            onFileDoubleClick: handleFileDoubleClick
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task {
                try? await fileService.listFiles()
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
