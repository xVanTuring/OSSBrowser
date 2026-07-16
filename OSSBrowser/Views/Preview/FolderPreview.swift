//
//  FolderPreview.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/14.
//

import SwiftUI

struct FolderPreview: View {
    let file: OSSFile

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("文件夹")
                    .font(.title2)
                    .fontWeight(.medium)

                Text(file.name)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            Text("文件夹本身没有可预览的内容。")
                .font(.callout)
                .foregroundColor(.secondary)

            Text("关闭此预览后，在文件列表中双击该文件夹即可查看其中的文件。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}