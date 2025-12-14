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
    @State private var selectedFile: OSSFile?
    @State private var lastClickTime: Date = Date()
    @State private var lastClickedFile: String?
    @State private var showingDeleteAlert = false
    @State private var filesToDelete: [OSSFile] = []
    @State private var fileToDelete: OSSFile?
    @State private var isShiftPressed = false
    @State private var isCommandPressed = false
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

    private var hasUploadCallback: Bool {
        return true
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 文件列表
                if isLoading && files.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Spacer()
                    }
                } else if files.isEmpty {
                    VStack {
                        Spacer()
                        ContentUnavailableView(
                            "空文件夹",
                            systemImage: "folder",
                            description: Text("这个文件夹还没有文件")
                        )
                        Spacer()
                    }
                } else {
                    // 使用自定义的列表视图
                    VStack(spacing: 0) {
                        // 表头
                        HStack(spacing: 0) {
                            // 名称列
                            Text("名称")
                                .font(.headline)
                                .padding(.leading, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // 修改日期列
                            Text("修改日期")
                                .font(.headline)
                                .frame(width: 200, alignment: .leading)

                            // 大小列
                            Text("大小")
                                .font(.headline)
                                .frame(width: 100, alignment: .trailing)
                                .padding(.trailing, 16)
                        }
                        .padding(.vertical, 8)

                        Divider()

                        // 文件列表内容 - 使用 ScrollView 确保从顶部开始
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {

                                // ForEach(files) { file in
                                ForEach(Array(files.enumerated()), id: \.element.id) {
                                    index, file in
                                    FileRowView(
                                        file: file,
                                        isSelected: selectedFiles.contains(file.id),
                                        selectedCount: selectedFiles.count,
                                        onClick: { handleFileClick(file, at: index) },
                                        onDownloadFile: onDownloadFile,
                                        onDownloadFolder: onDownloadFolder,
                                        onDelete: { handleDelete(file) },
                                        onBatchDelete: { handleBatchDelete() },
                                        onBatchDownload: { handleBatchDownload() },
                                        onCopyPath: onCopyPath,
                                        onCopyURL: onCopyURL,
                                        onCopyPresignedURL: onCopyPresignedURL
                                    )
                                    .background(
                                        // 如果选中，则使用选中颜色，否则根据行号交替显示
                                        selectedFiles.contains(file.id)
                                            ? Color(NSColor.selectedContentBackgroundColor).opacity(
                                                0.5)
                                            : (index % 2 == 0
                                                ? Color(Color.white.opacity(0.05))
                                                : Color(NSColor.clear))
                                    )
                                    .onTapGesture { event in
                                        handleFileClick(file, at: index)
                                    }
                                    .simultaneousGesture(
                                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                            .onChanged { _ in }
                                            .onEnded { _ in }
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                            handleDrop(providers: providers)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .focusable()
        .focusEffectDisabled(true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            updateModifierKeys()
        }
        .onKeyPress { key in
            if key.key == "a" && key.modifiers.contains(.command) {
                selectAll()
                return .handled
            }
            return .ignored
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
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
                Text(file.isDirectory
                    ? "确定要删除文件夹 \"\(file.name)\" 吗？此操作将删除文件夹及其所有内容。"
                    : "确定要删除文件 \"\(file.name)\" 吗？")
            } else {
                Text("确定要删除选中的 \(filesToDelete.count) 个项目吗？此操作不可撤销。")
            }
        }
    }

    private func handleFileClick(_ file: OSSFile, at index: Int) {
        let now = Date()
        let timeSinceLastClick = now.timeIntervalSince(lastClickTime)

        // 更新修饰键状态
        updateModifierKeys()

        // 检查是否是双击（在同一文件上，且间隔小于 0.5 秒）
        if lastClickedFile == file.id && timeSinceLastClick < 0.5 && !isShiftPressed && !isCommandPressed {
            // 双击
            onFileDoubleClick(file)
        } else {
            // 处理多选
            if isCommandPressed {
                // Command + 点击：切换选中状态
                if selectedFiles.contains(file.id) {
                    selectedFiles.remove(file.id)
                } else {
                    selectedFiles.insert(file.id)
                }
            } else if isShiftPressed && !selectedFiles.isEmpty {
                // Shift + 点击：范围选择
                if let lastClickedId = lastClickedFile,
                   let lastIndex = files.firstIndex(where: { $0.id == lastClickedId }) {
                    let startIndex = min(lastIndex, index)
                    let endIndex = max(lastIndex, index)

                    // 清空之前的选择
                    selectedFiles.removeAll()

                    // 选择范围内的所有文件
                    for i in startIndex...endIndex {
                        selectedFiles.insert(files[i].id)
                    }
                }
            } else {
                // 普通单击：单选
                selectedFiles = [file.id]
            }

            // 更新当前文件和回调
            selectedFile = file
            if selectedFiles.count == 1 {
                onFileSelect(file)
            }
        }

        lastClickTime = now
        lastClickedFile = file.id
    }

    private func updateModifierKeys() {
        let flags = NSEvent.modifierFlags
        isShiftPressed = flags.contains(.shift)
        isCommandPressed = flags.contains(.command)
    }

    private func selectAll() {
        // 创建包含所有文件ID的新集合（现在使用稳定的key作为ID）
        let allFileIds = Set(files.map { $0.id })
        selectedFiles = allFileIds
    }

    private func handleDelete(_ file: OSSFile) {
        fileToDelete = file
        showingDeleteAlert = true
    }

    private func handleBatchDelete() {
        filesToDelete = files.filter { selectedFiles.contains($0.id) }
        showingDeleteAlert = true
    }

    private func handleBatchDownload() {
        let selectedFilesList = files.filter { selectedFiles.contains($0.id) }
        onDownloadMultiple(selectedFilesList)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url else { return }
                    DispatchQueue.main.async {
                        if self.hasUploadCallback {
                            if self.isDirectory(at: url) {
                                self.onDropFolder(url)
                            } else {
                                self.onDropFile(url)
                            }
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
}

// 文件行视图
struct FileRowView: View {
    let file: OSSFile
    let isSelected: Bool
    let selectedCount: Int
    let onClick: () -> Void
    let onDownloadFile: (OSSFile) -> Void
    let onDownloadFolder: (OSSFile) -> Void
    let onDelete: () -> Void
    let onBatchDelete: () -> Void
    let onBatchDownload: () -> Void
    let onCopyPath: (OSSFile) -> Void
    let onCopyURL: (OSSFile) -> Void
    let onCopyPresignedURL: (OSSFile) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 名称列
            HStack(spacing: 8) {
                Image(systemName: file.iconName)
                    .foregroundColor(file.isDirectory ? .blue : .primary)
                    .frame(width: 16, height: 16)
                Text(file.name)
                    .fontWeight(file.isDirectory ? .medium : .regular)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 16)

            // 修改日期列
            Text(file.lastModified, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 200, alignment: .leading)

            // 大小列
            Text(file.fileSizeString)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            if selectedCount > 1 {
                // 多选时的菜单
                Button(action: {
                    onBatchDownload()
                }) {
                    Label("下载选中项 (\(selectedCount))", systemImage: "arrow.down.circle")
                }

                Divider()

                Button(action: {
                    onBatchDelete()
                }) {
                    Label("删除选中项", systemImage: "trash")
                }
                .foregroundColor(.red)
            } else {
                // 单选时的菜单
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

                Menu("复制") {
                    Button(action: {
                        onCopyPath(file)
                    }) {
                        Label("复制文件路径", systemImage: "doc.text")
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
                            Label("复制预签名地址", systemImage: "clock.badge.questionmark")
                        }
                    }
                }

                Divider()

                Button(action: {
                    onDelete()
                }) {
                    Label("删除", systemImage: "trash")
                }
                .foregroundColor(.red)
            }
        }
    }
}

#Preview {
    FileListView(
        files: [
            OSSFile(
                key: "folder1/", size: 0, lastModified: Date(), eTag: "", storageClass: "",
                isDirectory: true),
            OSSFile(
                key: "file1.txt", size: 1024, lastModified: Date(), eTag: "",
                storageClass: "Standard", isDirectory: false),
            OSSFile(
                key: "image.png", size: 2048, lastModified: Date(), eTag: "",
                storageClass: "Standard", isDirectory: false),
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
