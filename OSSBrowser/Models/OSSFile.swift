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

    // 文件类型图标
    var iconName: String {
        if isDirectory {
            return "folder.fill"
        }

        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "svg":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv", "wmv", "flv":
            return "video.fill"
        case "mp3", "wav", "aac", "m4a", "flac":
            return "music.note"
        case "pdf":
            return "doc.text.fill"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx":
            return "chart.bar.fill"
        case "ppt", "pptx":
            return "play.rectangle.fill"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox.fill"
        case "txt", "md", "rtf":
            return "doc.plaintext"
        case "swift", "py", "js", "html", "css", "json", "xml":
            return "code"
        default:
            return "doc.fill"
        }
    }
}