//
//  ImagePreview.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/14.
//

import SwiftUI
import AlibabaCloudOSS

struct ImagePreview: View {
    let file: OSSFile
    let bucketName: String
    let config: OSSConfiguration

    @State private var imageURL: URL?
    @State private var isLoadingImage = false
    @State private var imageLoadError: Error?
    @State private var shouldLoadLargeImage = false

    // 图片大小阈值：10MB
    private let imageThreshold: Int64 = 5 * 1024 * 1024

    var body: some View {
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
                largeImagePrompt
            } else if isLoadingImage {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = imageLoadError {
                errorView(error: error)
            }
        }
        .onAppear {
            if file.size <= imageThreshold {
                loadPreviewImage()
            }
        }
    }

    @ViewBuilder
    private var largeImagePrompt: some View {
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
    }

    @ViewBuilder
    private func errorView(error: Error) -> some View {
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