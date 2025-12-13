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
    @State private var imageURL: URL?
    @State private var isLoadingImage = false
    @State private var imageLoadError: Error?
    @State private var shouldLoadLargeImage = false

    // 图片大小阈值：10MB
    private let imageThreshold: Int64 = 10 * 1024 * 1024

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
                    folderPreview
                } else if isImageFile(file.name) {
                    // 图片预览
                    imagePreview
                } else {
                    // 其他文件预览
                    genericFilePreview
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(width: 600, height: 500)
        .onAppear {
            if isImageFile(file.name) && file.size <= imageThreshold {
                loadPreviewImage()
            }
        }
    }

    @ViewBuilder
    private var folderPreview: some View {
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

    @ViewBuilder
    private var imagePreview: some View {
        GeometryReader { geometry in
            if let imageURL = imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } placeholder: {
                    ProgressView()
                        .scaleEffect(1.5)
                }
                .clipped()
            } else if file.size > imageThreshold && !shouldLoadLargeImage {
                // 大图片提示
                VStack(spacing: 20) {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        Text("大图片文件")
                            .font(.title2)
                            .fontWeight(.medium)

                        Text("文件大小: \(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Button(action: {
                        shouldLoadLargeImage = true
                        loadPreviewImage()
                    }) {
                        HStack {
                            if isLoadingImage {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("加载中...")
                            } else {
                                Image(systemName: "arrow.down.circle")
                                Text("加载图片")
                            }
                        }
                        .font(.callout)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isLoadingImage)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoadingImage {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = imageLoadError {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("加载失败")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var genericFilePreview: some View {
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

            Text("此文件类型暂不支持预览")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func isImageFile(_ fileName: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "heif"]
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        return imageExtensions.contains(fileExtension)
    }

    private func loadPreviewImage() {
        guard isImageFile(file.name) else { return }

        isLoadingImage = true
        imageLoadError = nil

        Task {
            await generatePresignedURL()
        }
    }

    @MainActor
    private func generatePresignedURL() async {
        let ossConfig = Configuration.default()
            .withCredentialsProvider(StaticCredentialsProvider(
                accessKeyId: config.accessKeyId,
                accessKeySecret: config.accessKeySecret
            ))
            .withRegion(config.region)

        if let endpoint = config.endpoint {
            ossConfig.withEndpoint(endpoint)
        }

        let client = Client(ossConfig)

        do {
            let presignResult = try await client.presign(
                GetObjectRequest(
                    bucket: bucketName,
                    key: file.key
                ),
                Date().addingTimeInterval(3600) // 1小时有效期
            )

            imageURL = URL(string: presignResult.url)
            isLoadingImage = false
        } catch {
            imageLoadError = error
            isLoadingImage = false
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