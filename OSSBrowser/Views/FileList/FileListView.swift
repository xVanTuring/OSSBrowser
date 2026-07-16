//
//  FileListView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileListView: View {
    let files: [OSSFile]
    @Binding var selectedFiles: Set<String>
    let isLoading: Bool
    let hasMore: Bool
    let isLoadingMore: Bool
    let onLoadMore: () -> Void
    let onFileSelect: (OSSFile) -> Void
    let onFileDoubleClick: (OSSFile) -> Void
    let onDownloadFile: (OSSFile) -> Void
    let onDownloadFolder: (OSSFile) -> Void
    let onDeleteFile: (OSSFile) -> Void
    let onDeleteMultiple: ([OSSFile]) -> Void
    let onDownloadMultiple: ([OSSFile]) -> Void
    let onDropFile: (URL) -> Void?
    let onDropFolder: (URL) -> Void?
    let onCopyPath: (OSSFile) -> Void
    let onCopyURL: (OSSFile) -> Void
    let onCopyPresignedURL: (OSSFile) -> Void
    let onRenameFile: (OSSFile, String) -> Void
    let onPreview: (OSSFile) -> Void
    @Binding var isCreatingFolder: Bool
    let onCreateFolder: (String) -> Void
    let onRefresh: () -> Void
    let onUpload: () -> Void
    /// 当前搜索前缀（为空表示非搜索状态），用于区分「空文件夹」与「搜索无结果」
    var searchQuery: String = ""
    /// 列表加载失败信息（非 nil 且列表为空时显示错误态）
    var loadErrorMessage: String? = nil
    /// 错误态「重试」
    var onRetry: () -> Void = {}
    /// 搜索无结果时「清除搜索」
    var onClearSearch: () -> Void = {}

    @State private var showingDeleteAlert = false
    @State private var filesToDelete: [OSSFile] = []
    @State private var showingRenameAlert = false
    @State private var fileToRename: OSSFile?
    @State private var newFileName = ""

    // 用于 Table 的选择状态
    private var selectedFileIds: Binding<Set<String>> {
        Binding {
            selectedFiles
        } set: { newValue in
            selectedFiles = newValue
            // 触发选择回调
            if newValue.count == 1 {
                if let fileId = newValue.first,
                    let file = files.first(where: { $0.id == fileId })
                {
                    onFileSelect(file)
                }
            }
        }
    }

    private var dropHandler: FileDropHandler {
        FileDropHandler(
            onDropFile: onDropFile,
            onDropFolder: onDropFolder
        )
    }

    private var keyboardHandler: FileKeyboardHandler {
        FileKeyboardHandler(
            files: files,
            selectedFiles: $selectedFiles,
            onBatchDelete: handleBatchDelete,
            onPreview: onPreview,
            onOpen: onFileDoubleClick
        )
    }

    @State private var emptyFolderDropActive = false

    // 当前目录下已存在的文件夹名（小写），用于内联新建的重名校验
    private var existingFolderNames: Set<String> {
        Set(files.filter { $0.isDirectory }.map { $0.name.lowercased() })
    }

    // 空白处 / 空文件夹的背景右键菜单
    @ViewBuilder
    private func backgroundContextMenu() -> some View {
        Button {
            isCreatingFolder = true
        } label: {
            Label("新建文件夹", systemImage: "folder.badge.plus")
        }
        Button {
            onUpload()
        } label: {
            Label("上传文件…", systemImage: "arrow.up.doc")
        }
        Divider()
        Button {
            onRefresh()
        } label: {
            Label("刷新", systemImage: "arrow.clockwise")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 内联「新建文件夹」行
            if isCreatingFolder {
                NewFolderInlineRow(
                    existingNames: existingFolderNames,
                    onCommit: { name in onCreateFolder(name) },
                    onCancel: { isCreatingFolder = false }
                )
            }

            // 文件列表
            if isLoading && files.isEmpty {
                FileListStates.LoadingView()
            } else if let loadErrorMessage, files.isEmpty {
                FileListStates.ErrorView(message: loadErrorMessage, onRetry: onRetry)
            } else if files.isEmpty && !searchQuery.isEmpty {
                FileListStates.SearchEmptyView(query: searchQuery, onClear: onClearSearch)
            } else if files.isEmpty {
                FileListStates.EmptyFolderView(onUpload: onUpload)
                    .onDrop(of: [.fileURL], isTargeted: $emptyFolderDropActive) { providers in
                        dropHandler.handleDrop(providers: providers)
                    }
                    .background(emptyFolderDropActive ? Color.accentColor.opacity(0.1) : Color.clear)
                    .contextMenu { backgroundContextMenu() }
            } else {
                FileTable(
                    files: files,
                    selectedFiles: $selectedFiles,
                    onFileDoubleClick: onFileDoubleClick,
                    dropHandler: dropHandler,
                    keyboardHandler: keyboardHandler,
                    onLoadMore: hasMore ? onLoadMore : nil
                )
                .contextMenu(forSelectionType: OSSFile.ID.self) { clickedItems in
                    if clickedItems.isEmpty {
                        // 右键空白处 → 背景菜单
                        backgroundContextMenu()
                    } else {
                    FileContextMenu(
                        files: files,
                        selectedFiles: clickedItems,
                        onDownloadFile: onDownloadFile,
                        onDownloadFolder: onDownloadFolder,
                        onCopyPath: onCopyPath,
                        onCopyURL: onCopyURL,
                        onCopyPresignedURL: onCopyPresignedURL,
                        onPreview: onPreview,
                        onOpen: onFileDoubleClick,
                        onRename: { file in
                            fileToRename = file
                            newFileName = file.name
                            showingRenameAlert = true
                        },
                        onDelete: { file in
                            filesToDelete = [file]
                            showingDeleteAlert = true
                        },
                        onBatchDelete: handleBatchDelete,
                        onBatchDownload: handleBatchDownload
                    )
                    }
                } primaryAction: { items in
                    // 双击处理
                    if let fileId = items.first,
                       let file = files.first(where: { $0.id == fileId }) {
                        onFileDoubleClick(file)
                    }
                }

                // 加载更多状态提示
                if isLoadingMore {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("加载中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 刷新已有内容时的加载指示：浮在列表顶部，不占布局、不推动列表
        .overlay(alignment: .top) {
            if isLoading && !files.isEmpty {
                ProgressView()
                    .progressViewStyle(.linear)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isLoading)
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if !filesToDelete.isEmpty {
                    if filesToDelete.count == 1, let file = filesToDelete.first {
                        onDeleteFile(file)
                    } else {
                        onDeleteMultiple(filesToDelete)
                    }
                }
            }
        } message: {
            if filesToDelete.count == 1, let file = filesToDelete.first {
                Text(
                    file.isDirectory
                        ? "确定要删除文件夹 \"\(file.name)\" 吗？此操作将删除文件夹及其所有内容。"
                        : "确定要删除文件 \"\(file.name)\" 吗？")
            } else {
                Text("确定要删除选中的 \(filesToDelete.count) 个项目吗？此操作不可撤销。")
            }
        }
        .alert("重命名", isPresented: $showingRenameAlert) {
            TextField("新名称", text: $newFileName)
            Button("取消", role: .cancel) {}
            Button("确定") {
                if let file = fileToRename, !newFileName.isEmpty {
                    onRenameFile(file, newFileName)
                }
            }
        } message: {
            if let file = fileToRename {
                Text("为 \"\(file.name)\" 输入新名称")
            }
        }
    }

    // MARK: - Private Methods
    private func handleBatchDelete() {
        filesToDelete = files.filter { selectedFiles.contains($0.id) }
        showingDeleteAlert = true
    }

    private func handleBatchDownload() {
        let selectedFilesList = files.filter { selectedFiles.contains($0.id) }
        onDownloadMultiple(selectedFilesList)
    }
}

#Preview {
    FileListView(
        files: [
            OSSFile(
                key: "folder1/",
                size: 0,
                lastModified: Date(),
                eTag: "",
                storageClass: "",
                isDirectory: true),
            OSSFile(
                key: "file1.txt",
                size: 1024,
                lastModified: Date(),
                eTag: "",
                storageClass: "Standard",
                isDirectory: false),
            OSSFile(
                key: "image.png",
                size: 2048,
                lastModified: Date(),
                eTag: "",
                storageClass: "Standard",
                isDirectory: false),
        ],
        selectedFiles: .constant([]),
        isLoading: false,
        hasMore: false,
        isLoadingMore: false,
        onLoadMore: {},
        onFileSelect: { _ in },
        onFileDoubleClick: { _ in },
        onDownloadFile: { _ in },
        onDownloadFolder: { _ in },
        onDeleteFile: { _ in },
        onDeleteMultiple: { _ in },
        onDownloadMultiple: { _ in },
        onDropFile: { _ in },
        onDropFolder: { _ in },
        onCopyPath: { _ in },
        onCopyURL: { _ in },
        onCopyPresignedURL: { _ in },
        onRenameFile: { _, _ in },
        onPreview: { _ in },
        isCreatingFolder: .constant(false),
        onCreateFolder: { _ in },
        onRefresh: {},
        onUpload: {}
    )
}
