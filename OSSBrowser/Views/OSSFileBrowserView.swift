//
//  OSSFileBrowserView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI

struct OSSFileBrowserView: View {
    let bucket: BucketItem
    let config: OSSConfiguration

    @StateObject private var fileService: OSSFileService
    @State private var selectedFiles: Set<String> = []
    @State private var showingCreateFolder = false

    init(bucket: BucketItem, config: OSSConfiguration) {
        self.bucket = bucket
        self.config = config
        self._fileService = StateObject(wrappedValue: OSSFileService(config: config, bucketName: bucket.name))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 集成路径导航的工具栏
            FileBrowserToolbar(
                fileService: fileService,
                onGoBack: goBack,
                onGoForward: goForward,
                onNavigate: navigateToPath,
                onRefresh: refresh,
                onCreateFolder: { showingCreateFolder = true }
            )
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // 文件列表 - 使用最大高度确保占据可用空间
            FileListView(
                files: fileService.files,
                selectedFiles: $selectedFiles,
                isLoading: fileService.isLoading,
                onFileSelect: handleFileSelect,
                onFileDoubleClick: handleFileDoubleClick
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // 状态栏
            StatusBar(
                itemCount: fileService.files.count,
                selectedCount: selectedFiles.count,
                isLoading: fileService.isLoading
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task {
                try? await fileService.listFiles()
            }
        }
        .alert("创建文件夹", isPresented: $showingCreateFolder) {
            TextField("文件夹名称", text: $folderName)
            Button("创建") {
                createFolder()
            }
            .disabled(folderName.isEmpty)
            Button("取消", role: .cancel) { }
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
    }

    // MARK: - Actions
    private func goBack() {
        Task {
            do {
                try await fileService.goBack()
            } catch {
                fileService.error = error
            }
        }
    }

    private func goForward() {
        Task {
            do {
                try await fileService.goForward()
            } catch {
                fileService.error = error
            }
        }
    }

    private func refresh() {
        Task {
            try? await fileService.listFiles(at: fileService.currentPath)
        }
    }

    private func navigateToPath(_ path: String) {
        Task {
            try? await fileService.listFiles(at: path)
        }
    }

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
    @State private var folderName = ""
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

// MARK: - File Browser Toolbar
struct FileBrowserToolbar: View {
    @ObservedObject var fileService: OSSFileService
    let onGoBack: () -> Void
    let onGoForward: () -> Void
    let onNavigate: (String) -> Void
    let onRefresh: () -> Void
    let onCreateFolder: () -> Void

    var canGoBack: Bool {
        fileService.canGoBack
    }

    var canGoForward: Bool {
        return fileService.canGoForward
    }

    var body: some View {
        HStack(spacing: 12) {
            // 导航按钮组
            HStack(spacing: 8) {
                Button(action: onGoBack) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack || fileService.isLoading)
                .help("返回上级目录")

                Button(action: onGoForward) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward || fileService.isLoading)
                .help("前进")
            }

            // 路径导航 - 可滚动
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // 根路径
                    Button("/") {
                        onNavigate("")
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)

                    // 路径组件
                    ForEach(pathComponents, id: \.self) { component in
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Button(component) {
                            let path = pathForComponent(component)
                            onNavigate(path)
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer()

            // 操作按钮组
            HStack(spacing: 8) {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(fileService.isLoading)
                .help("刷新")

                Button(action: onCreateFolder) {
                    Image(systemName: "plus")
                }
                .disabled(fileService.isLoading)
                .help("新建文件夹")
            }
        }
    }

    private var pathComponents: [String] {
        return fileService.currentPath.components(separatedBy: "/").filter { !$0.isEmpty }
    }

    private func pathForComponent(_ component: String) -> String {
        var path = ""
        for comp in pathComponents {
            path += comp + "/"
            if comp == component {
                break
            }
        }
        return path
    }
}


// MARK: - Status Bar
struct StatusBar: View {
    let itemCount: Int
    let selectedCount: Int
    let isLoading: Bool

    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                Text("加载中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(itemCount) 个项目")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if selectedCount > 0 {
                    Text("· \(selectedCount) 个已选择")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    OSSFileBrowserView(
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
        )
    )
}