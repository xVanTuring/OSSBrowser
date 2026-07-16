//
//  FileContextMenu.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/14.
//

import SwiftUI

struct FileContextMenu: View {
    let files: [OSSFile]
    let selectedFiles: Set<String>
    let onDownloadFile: (OSSFile) -> Void
    let onDownloadFolder: (OSSFile) -> Void
    let onCopyPath: (OSSFile) -> Void
    let onCopyURL: (OSSFile) -> Void
    let onCopyPresignedURL: (OSSFile) -> Void
    let onPreview: (OSSFile) -> Void
    let onOpen: (OSSFile) -> Void
    let onRename: (OSSFile) -> Void
    let onDelete: (OSSFile) -> Void
    let onBatchDelete: () -> Void
    let onBatchDownload: () -> Void

    var body: some View {
        if selectedFiles.count > 1 {
            // 多选菜单
            Button(action: {
                onBatchDownload()
            }) {
                Label("下载选中项 (\(selectedFiles.count))", systemImage: "arrow.down.circle")
            }

            Divider()

            Button(
                role: .destructive,
                action: {
                    onBatchDelete()
                }
            ) {
                Label("删除选中项", systemImage: "trash")
            }
        } else if let file = files.first(where: { selectedFiles.contains($0.id) }) {
            // 单选菜单
            if file.isDirectory {
                Button(action: {
                    onOpen(file)
                }) {
                    Label("打开", systemImage: "folder")
                }
            } else {
                Button(action: {
                    onPreview(file)
                }) {
                    Label("预览", systemImage: "eye")
                }
            }

            Divider()

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

            Button(action: {
                onRename(file)
            }) {
                Label("重命名", systemImage: "pencil")
            }

            Divider()

            Button(
                role: .destructive,
                action: {
                    onDelete(file)
                }
            ) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}