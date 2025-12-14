//
//  FilePreviewWindow.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/14.
//

import SwiftUI
import AlibabaCloudOSS

struct FilePreviewWindow: View {
    let file: OSSFile
    let bucketName: String
    let config: OSSConfiguration
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(file.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 内容区域
            Group {
                if file.isDirectory {
                    // 文件夹预览
                    FolderPreview(file: file)
                } else if isImageFile(file.name) {
                    // 图片预览
                    ImagePreview(file: file, bucketName: bucketName, config: config)
                } else {
                    // 其他文件预览
                    GenericFilePreview(file: file)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(width: 600, height: 500)
    }

    private func isImageFile(_ fileName: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "heif"]
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        return imageExtensions.contains(fileExtension)
    }
}

#Preview {
    FilePreviewWindow(
        file: OSSFile(
            key: "test.jpg",
            size: 1024 * 1024,
            lastModified: Date(),
            eTag: "",
            storageClass: "Standard",
            isDirectory: false
        ),
        bucketName: "test-bucket",
        config: OSSConfiguration(
            name: "Test",
            accessKeyId: "",
            accessKeySecret: "",
            region: "cn-hangzhou"
        )
    )
}