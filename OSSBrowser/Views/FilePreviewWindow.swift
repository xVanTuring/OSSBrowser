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

            // 内容区域：按文件分类路由到对应预览
            Group {
                switch file.previewKind {
                case .folder:
                    FolderPreview(file: file)
                case .image:
                    ImagePreview(file: file, bucketName: bucketName, config: config)
                case .video:
                    VideoPreview(file: file, bucketName: bucketName, config: config)
                case .audio:
                    AudioPreview(file: file, bucketName: bucketName, config: config)
                case .pdf:
                    PDFPreview(file: file, bucketName: bucketName, config: config)
                case .text:
                    TextPreview(file: file, bucketName: bucketName, config: config)
                case .none:
                    GenericFilePreview(file: file)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(minWidth: 600, idealWidth: 720, minHeight: 500, idealHeight: 620)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) {
            dismiss()
            return .handled
        }
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