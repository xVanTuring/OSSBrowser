//
//  FileTypeHelper.swift
//  OSSBrowser
//
//  统一的文件类型分类：由扩展名推导「分类 / 图标 / 类型名称 / 预览方式」，
//  避免在图标、预览、右键菜单等多处各自维护扩展名列表。
//

import Foundation
import SwiftUI

/// 文件预览方式
enum FilePreviewKind {
    case folder
    case image
    case video
    case audio
    case pdf
    case text
    case none  // 暂不支持内联预览
}

/// 文件分类
enum FileCategory {
    case folder
    case image
    case video
    case audio
    case pdf
    case text
    case code
    case archive
    case document      // Word 等
    case spreadsheet   // Excel 等
    case presentation  // PPT 等
    case other

    /// 从扩展名（小写、不含点）推导分类
    static func from(extension ext: String) -> FileCategory {
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "tiff", "tif", "heic", "heif", "ico":
            return .image
        case "mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm", "mpg", "mpeg", "3gp":
            return .video
        case "mp3", "wav", "aac", "m4a", "flac", "aiff", "aif", "caf", "ogg", "wma":
            return .audio
        case "pdf":
            return .pdf
        case "txt", "md", "markdown", "log", "csv", "rtf":
            return .text
        case "swift", "py", "js", "ts", "jsx", "tsx", "html", "htm", "css", "scss",
             "json", "xml", "yaml", "yml", "toml", "sh", "bash", "c", "cpp", "h", "hpp",
             "java", "kt", "go", "rs", "rb", "php", "sql", "plist":
            return .code
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "pkg":
            return .archive
        case "doc", "docx", "pages":
            return .document
        case "xls", "xlsx", "numbers":
            return .spreadsheet
        case "ppt", "pptx", "key":
            return .presentation
        default:
            return .other
        }
    }

    /// SF Symbol 图标名
    var iconName: String {
        switch self {
        case .folder:       return "folder.fill"
        case .image:        return "photo.fill"
        case .video:        return "film.fill"
        case .audio:        return "music.note"
        case .pdf:          return "doc.richtext.fill"
        case .text:         return "doc.plaintext.fill"
        case .code:         return "chevron.left.forwardslash.chevron.right"
        case .archive:      return "archivebox.fill"
        case .document:     return "doc.text.fill"
        case .spreadsheet:  return "tablecells.fill"
        case .presentation: return "play.rectangle.fill"
        case .other:        return "doc.fill"
        }
    }

    /// 中文类型名称（用于详情/无障碍描述）
    var displayName: String {
        switch self {
        case .folder:       return "文件夹"
        case .image:        return "图片"
        case .video:        return "视频"
        case .audio:        return "音频"
        case .pdf:          return "PDF 文档"
        case .text:         return "文本"
        case .code:         return "代码"
        case .archive:      return "压缩包"
        case .document:     return "文档"
        case .spreadsheet:  return "表格"
        case .presentation: return "演示文稿"
        case .other:        return "文件"
        }
    }

    /// 列表图标着色
    var tint: Color {
        switch self {
        case .folder:       return .blue
        case .image:        return .green
        case .video:        return .purple
        case .audio:        return .pink
        case .pdf:          return .red
        case .text:         return .secondary
        case .code:         return .teal
        case .archive:      return .orange
        case .document:     return .blue
        case .spreadsheet:  return .green
        case .presentation: return .orange
        case .other:        return .secondary
        }
    }

    /// 内联预览方式
    var previewKind: FilePreviewKind {
        switch self {
        case .folder:  return .folder
        case .image:   return .image
        case .video:   return .video
        case .audio:   return .audio
        case .pdf:     return .pdf
        case .text, .code: return .text
        default:       return .none
        }
    }
}
