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
    @State private var sortedFiles: [OSSFile] = []
    @State private var sortOrder: [KeyPathComparator<OSSFile>] = [.init(\.name)]
    @State private var showingDeleteAlert = false
    @State private var filesToDelete: [OSSFile] = []
    @State private var dropAreaActive = false
    let isLoading: Bool
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

    fileprivate func LoadingView() -> some View {
        return VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    fileprivate func EmptyFolderView() -> some View {
        return VStack {
            Spacer()
            ContentUnavailableView(
                "空文件夹",
                systemImage: "folder",
                description: Text("这个文件夹还没有文件")
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }
    fileprivate func TableFileListView() -> some View {
        return Table(sortedFiles, selection: selectedFileIds, sortOrder: $sortOrder) {
            // 名称列
            TableColumn("名称", value: \.name) { file in
                HStack(spacing: 8) {
                    Image(systemName: file.iconName)
                        .foregroundColor(file.isDirectory ? .blue : .primary)
                        .frame(width: 16, height: 16)

                    Text(file.name)
                        .font(.body)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .width(min: 300, ideal: 500, max: 800)

            // 修改日期列
            TableColumn("修改日期", value: \.lastModified) { file in
                Text(file.lastModified, format: .dateTime)
                    .foregroundColor(.secondary)
            }
            .width(min: 150, ideal: 180, max: 250)

            // 大小列
            TableColumn("大小", value: \.size) { file in
                Text(file.fileSizeString)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100, max: 150)
        }
        .contextMenu(forSelectionType: OSSFile.ID.self) { items in
            contextMenuContent
        } primaryAction: { items in
            // 双击处理：如果是单个文件，执行双击回调
            if let fileId = items.first,
               let file = files.first(where: { $0.id == fileId }) {
                onFileDoubleClick(file)
            }
        }
        .onChange(of: sortOrder) { _, newOrder in
            withAnimation(.easeInOut(duration: 0.2)) {
                sortedFiles = files.sorted(using: newOrder)
            }
        }
        .onChange(of: files) { _, newFiles in
            withAnimation(.easeInOut(duration: 0.2)) {
                sortedFiles = newFiles.sorted(using: sortOrder)
            }
        }
        .onAppear {
            sortedFiles = files.sorted(using: sortOrder)
        }
        .tableStyle(.inset)
        .alternatingRowBackgrounds()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $dropAreaActive) { providers in
            handleDrop(providers: providers)
        }
        .background(dropAreaActive ? Color.accentColor.opacity(0.1) : Color.clear)
        .onKeyPress { key in
            handleKeyPress(key)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 文件列表
            if isLoading && files.isEmpty {
                LoadingView()
            } else if files.isEmpty {
                EmptyFolderView()
            } else {
                TableFileListView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

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
    }

    // MARK: - Context Menu
    @ViewBuilder
    private var contextMenuContent: some View {
        if selectedFiles.count > 1 {
            // 多选菜单
            Button(action: {
                handleBatchDownload()
            }) {
                Label("下载选中项 (\(selectedFiles.count))", systemImage: "arrow.down.circle")
            }

            Divider()

            Button(
                role: .destructive,
                action: {
                    handleBatchDelete()
                }
            ) {
                Label("删除选中项", systemImage: "trash")
            }
        } else if let file = files.first(where: { selectedFiles.contains($0.id) }) {
            // 单选菜单
            if file.isDirectory {
                Button(action: {
                    onDownloadFolder(file)
                }) {
                    Label("下载文件夹", systemImage: "arrow.down.circle")
                }
            } else {
                Button(action: {
                    onDownloadFile(file)
                }) {
                    Label("下载", systemImage: "arrow.down.circle")
                }
            }

            Divider()

            // 复制菜单
            Menu("复制") {
                Button(action: {
                    onCopyPath(file)
                }) {
                    Label("复制文件路径", systemImage: "doc.on.doc")
                }

                Button(action: {
                    onCopyURL(file)
                }) {
                    Label("复制文件地址", systemImage: "link")
                }

                if !file.isDirectory {
                    Button(action: {
                        onCopyPresignedURL(file)
                    }) {
                        Label("复制预签名地址", systemImage: "timer")
                    }
                }
            }

            Divider()

            Button(
                role: .destructive,
                action: {
                    filesToDelete = [file]
                    showingDeleteAlert = true
                }
            ) {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: - Private Methods
    private func handleKeyPress(_ key: KeyPress) -> KeyPress.Result {
        // Command+A 全选
        if key.key == "a" && key.modifiers.contains(.command) {
            selectedFiles = Set(files.map { $0.id })
            return .handled
        }

        // Delete 键删除选中项
        if key.key == .delete {
            if !selectedFiles.isEmpty {
                handleBatchDelete()
                return .handled
            }
        }
        if key.key == .return {
            print("clicked enter")
            return .handled
        }

        // 方向键导航 - Table 已经内置支持
        return .ignored
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url else { return }
                    DispatchQueue.main.async {
                        if isDirectory(at: url) {
                            onDropFolder(url)
                        } else {
                            onDropFile(url)
                        }
                    }
                }
            }
        }
        return true
    }

    private func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

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
        onCopyPresignedURL: { _ in }
    )
}
