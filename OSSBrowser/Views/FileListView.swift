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
    let isLoading: Bool
    let onFileSelect: (OSSFile) -> Void
    let onFileDoubleClick: (OSSFile) -> Void

    var body: some View {
        ZStack {
            // 文件列表
            if isLoading && files.isEmpty {
                ProgressView()
                    .scaleEffect(1.2)
            } else if files.isEmpty {
                ContentUnavailableView(
                    "空文件夹",
                    systemImage: "folder",
                    description: Text("这个文件夹还没有文件")
                )
            } else {
                Table(files) {
                    TableColumn("") { file in
                        Image(systemName: file.iconName)
                            .foregroundColor(file.isDirectory ? .blue : .primary)
                            .frame(width: 20)
                    }
                    .width(20)

                    TableColumn("名称") { file in
                        HStack {
                            Image(systemName: file.iconName)
                                .foregroundColor(file.isDirectory ? .blue : .primary)
                                .frame(width: 20)
                            Text(file.name)
                                .fontWeight(file.isDirectory ? .medium : .regular)
                        }
                    }

                    TableColumn("修改日期") { file in
                        Text(file.lastModified, style: .date)
                            .font(.caption)
                    }
                    .width(min: 150, ideal: 200)

                    TableColumn("大小") { file in
                        Text(file.fileSizeString)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .width(min: 80, ideal: 100)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .cornerRadius(0)
                .onTapGesture(count: 2) { location in
                    // 找到被点击的文件
                    if let index = findFileIndex(at: location) {
                        let file = files[index]
                        onFileDoubleClick(file)
                    }
                }
            }
        }
    }

    // 找到给定位置对应的文件索引（简化版，实际实现可能需要更复杂的逻辑）
    private func findFileIndex(at location: CGPoint) -> Int? {
        // 这是一个简化实现，实际应该根据点击位置计算行索引
        // 这里暂时返回 nil，让用户通过双击列表项来触发
        return nil
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