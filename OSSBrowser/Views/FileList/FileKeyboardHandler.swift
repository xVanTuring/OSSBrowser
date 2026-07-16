//
//  FileKeyboardHandler.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/14.
//

import SwiftUI

struct FileKeyboardHandler {
    let files: [OSSFile]
    @Binding var selectedFiles: Set<String>
    let onBatchDelete: () -> Void
    let onPreview: (OSSFile) -> Void
    let onOpen: (OSSFile) -> Void

    func handleKeyPress(_ key: KeyPress) -> KeyPress.Result {
        // Command+A 全选
        if key.key == "a" && key.modifiers.contains(.command) {
            selectedFiles = Set(files.map { $0.id })
            return .handled
        }

        // Delete 键删除选中项
        if key.key == .delete {
            if !selectedFiles.isEmpty {
                onBatchDelete()
                return .handled
            }
        }
        if key.key == .space {
            // 如果只有一个文件被选中，打开预览
            if selectedFiles.count == 1,
               let fileId = selectedFiles.first,
               let file = files.first(where: { $0.id == fileId }) {
                onPreview(file)
                return .handled
            }
        }

        // 回车：打开选中项（文件夹进入 / 文件预览）
        if key.key == .return {
            if selectedFiles.count == 1,
               let fileId = selectedFiles.first,
               let file = files.first(where: { $0.id == fileId }) {
                onOpen(file)
                return .handled
            }
        }

        // 方向键导航 - Table 已经内置支持
        return .ignored
    }
}
