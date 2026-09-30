//
//  FileBackgroundMenu.swift
//  OSSBrowser
//
//  文件列表中「作用于当前目录」的菜单项：新建文件夹、上传。
//  右键空白处 / 空文件夹时单独显示；右键文件时附加在菜单末尾。
//

import SwiftUI

struct FileBackgroundMenu: View {
    let onNewFolder: () -> Void
    let onUpload: () -> Void
    /// 为 nil 时不显示「刷新」（右键文件时不需要）
    var onRefresh: (() -> Void)? = nil

    var body: some View {
        Button {
            onNewFolder()
        } label: {
            Label("新建文件夹", systemImage: "folder.badge.plus")
        }
        Button {
            onUpload()
        } label: {
            Label("上传文件…", systemImage: "arrow.up.doc")
        }
        if let onRefresh {
            Divider()
            Button {
                onRefresh()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
        }
    }
}
