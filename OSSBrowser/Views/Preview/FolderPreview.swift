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
            }

            Text("文件夹内的内容需要打开查看")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}