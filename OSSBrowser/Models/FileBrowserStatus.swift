//
//  FileBrowserStatus.swift
//  OSSBrowser
//
//  文件浏览区向外（标题栏、详情栏）同步的状态快照。
//

import Foundation

struct FileBrowserStatus: Equatable {
    var itemCount = 0
    var selectedCount = 0
    var isLoading = false
    /// 当前目录（相对 bucket 根，可能带结尾 "/"；根目录为空串）
    var currentPath = ""
    /// 仅单选时有值
    var selectedFile: OSSFile?

    /// 当前目录名；根目录返回 nil
    var currentFolderName: String? {
        currentPath.split(separator: "/").last.map(String.init)
    }
}
