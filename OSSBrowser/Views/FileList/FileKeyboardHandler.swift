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

//        if key.key == .return {
//            print("clicked enter")
//            return .handled
//        }

        // 方向键导航 - Table 已经内置支持
        return .ignored
    }
}
