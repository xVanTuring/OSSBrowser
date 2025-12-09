//
//  FileListView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI

struct FileListView: View {
    let files: [OSSFile]
    @Binding var selectedFiles: Set<String>
    @State private var selectedFile: OSSFile?
    @State private var lastClickTime: Date = Date()
    @State private var lastClickedFile: String?
    let isLoading: Bool
    let onFileSelect: (OSSFile) -> Void
    let onFileDoubleClick: (OSSFile) -> Void

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
                        .background(Color(NSColor.controlBackgroundColor))

                        Divider()

                        // 文件列表内容 - 使用 ScrollView 确保从顶部开始
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                                ForEach(files) { file in
                                    FileRowView(
                                        file: file,
                                        isSelected: selectedFile?.id == file.id,
                                        onClick: { handleFileClick(file) }
                                    )
                                    .background(
                                        selectedFile?.id == file.id ?
                                        Color(NSColor.selectedContentBackgroundColor).opacity(0.5) :
                                        Color.clear
                                    )
                                    .onTapGesture {
                                        handleFileClick(file)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleFileClick(_ file: OSSFile) {
        let now = Date()
        let timeSinceLastClick = now.timeIntervalSince(lastClickTime)

        // 检查是否是双击（在同一文件上，且间隔小于 0.5 秒）
        if lastClickedFile == file.id.uuidString && timeSinceLastClick < 0.5 {
            // 双击
            onFileDoubleClick(file)
        } else {
            // 单击
            selectedFile = file
            selectedFiles = [file.id.uuidString]
            onFileSelect(file)
        }

        lastClickTime = now
        lastClickedFile = file.id.uuidString
    }
}

// 文件行视图
struct FileRowView: View {
    let file: OSSFile
    let isSelected: Bool
    let onClick: () -> Void

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
    }
}

#Preview {
    FileListView(
        files: [
            OSSFile(key: "folder1/", size: 0, lastModified: Date(), eTag: "", storageClass: "", isDirectory: true),
            OSSFile(key: "file1.txt", size: 1024, lastModified: Date(), eTag: "", storageClass: "Standard", isDirectory: false),
            OSSFile(key: "image.png", size: 2048, lastModified: Date(), eTag: "", storageClass: "Standard", isDirectory: false)
        ],
        selectedFiles: .constant([]),
        isLoading: false,
        onFileSelect: { _ in },
        onFileDoubleClick: { _ in }
    )
}