//
//  OSSFile.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import Foundation

struct OSSFile: Identifiable, Hashable {
    var id: String { key } // 使用key作为稳定的ID
    let key: String
    let size: Int64
    let lastModified: Date
    let eTag: String
    let storageClass: String
    let isDirectory: Bool

    // 计算属性
    var name: String {
        if isDirectory {
            return key.trimmingCharacters(in: ["/"]).components(separatedBy: "/").last ?? key
        } else {
            return URL(string: key)?.lastPathComponent ?? key
        }
    }

    var path: String {
        return key
    }

    var parentPath: String? {
        if key.contains("/") {
            let components = key.components(separatedBy: "/")
            if components.count > 1 {
                let parentComponents = components.dropLast()
                return parentComponents.joined(separator: "/") + "/"
            }
        }
        return ""
    }

    var fileSizeString: String {
        if isDirectory {
            return "—"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    // 文件扩展名
    var fileExtension: String {
        if isDirectory {
            return ""
        }
        return (name as NSString).pathExtension.lowercased()
    }

    // 文件分类（统一由 FileTypeHelper 推导）
    var category: FileCategory {
        isDirectory ? .folder : FileCategory.from(extension: fileExtension)
    }

    // 文件类型图标
    var iconName: String {
        category.iconName
    }

    // 中文类型名称
    var typeLabel: String {
        category.displayName
    }

    // 内联预览方式
    var previewKind: FilePreviewKind {
        category.previewKind
    }
}

// MARK: - 内联新建文件夹草稿
extension OSSFile {
    /// 内联「新建文件夹」草稿行使用的哨兵 key（正常对象 key 不会包含该字符）
    static let draftFolderKey = "\u{0}__oss_browser_new_folder__"

    /// 是否为内联新建草稿行
    var isDraftFolder: Bool { key == OSSFile.draftFolderKey }
}