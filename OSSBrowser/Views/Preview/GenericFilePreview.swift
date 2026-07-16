//
//  GenericFilePreview.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/14.
//

import SwiftUI

struct GenericFilePreview: View {
    let file: OSSFile

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: file.iconName)
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text(file.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("大小")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(file.fileSizeString)
                            .font(.callout)
                            .fontWeight(.medium)
                    }

                    VStack(spacing: 4) {
                        Text("修改日期")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(file.lastModified, style: .date)
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                }
            }

            Text("\(file.typeLabel) · 暂不支持内联预览")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("可在偏好设置（⌘,）切换为 QuickLook 预览，或下载后打开")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}