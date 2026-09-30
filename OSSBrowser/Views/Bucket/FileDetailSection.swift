//
//  FileDetailSection.swift
//  OSSBrowser
//
//  详情栏中「选中文件」的信息：大小、路径（可复制）、上传时间。
//

import SwiftUI
import AppKit

struct FileDetailSection: View {
    let file: OSSFile

    @State private var pathCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: file.iconName)
                    .foregroundColor(file.category.tint)
                Text(file.name)
                    .font(.headline)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            if !file.isDirectory {
                HStack {
                    Label("大小", systemImage: "internaldrive")
                    Spacer()
                    Text(file.fileSizeString)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                HStack {
                    Label("上传时间", systemImage: "clock")
                    Spacer()
                    Text(file.lastModified, format: .dateTime)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("路径", systemImage: "folder")
                    Spacer()
                    Button {
                        copyPath()
                    } label: {
                        Image(systemName: pathCopied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("复制路径")
                }
                Text(file.key)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.body)
        // 切换选中文件时复位复制状态
        .onChange(of: file.id) { pathCopied = false }
    }

    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(file.key, forType: .string)
        pathCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            pathCopied = false
        }
    }
}
