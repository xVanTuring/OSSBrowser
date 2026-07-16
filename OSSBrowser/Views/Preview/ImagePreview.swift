//
//  ImagePreview.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/14.
//

import SwiftUI
import AlibabaCloudOSS
import AppKit

struct ImagePreview: View {
    let file: OSSFile
    let bucketName: String
    let config: OSSConfiguration

    @State private var imageURL: URL?
    @State private var isLoadingImage = false
    @State private var imageLoadError: Error?
    @State private var shouldLoadLargeImage = false
    @State private var imageDimensions: CGSize?

    // 图片大小阈值：10MB
    private let imageThreshold: Int64 = 5 * 1024 * 1024

    var body: some View {
        VStack(spacing: 0) {
            // 主内容区域
            GeometryReader { geometry in
                ZStack {
                    if let imageURL = imageURL {
                        AsyncImage(url: imageURL) { image in
                            if let dimensions = imageDimensions,
                               shouldShowActualSize(dimensions: dimensions, containerSize: geometry.size) {
                                // 小图：显示实际尺寸，居中
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: dimensions.width, height: dimensions.height)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                // 大图：适配容器大小
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        } placeholder: {
                            ProgressView()
                                .scaleEffect(1.5)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .clipped()
                    } else if file.size > imageThreshold && !shouldLoadLargeImage {
                        // 大图片提示
                        largeImagePrompt
                    } else if isLoadingImage {
                        VStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.5)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = imageLoadError {
                        errorView(error: error)
                    }
                }
            }

            // 图片信息栏 - 始终显示
            HStack {
                if let dimensions = imageDimensions {
                    Text("尺寸: \(Int(dimensions.width)) × \(Int(dimensions.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("尺寸: N/A")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("文件大小: \(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
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
        imageDimensions = nil // 重置尺寸信息

        Task {
            await generatePresignedURL()
        }
    }

    @MainActor
    private func generatePresignedURL() async {
        do {
            imageURL = try await OSSPresigner.presignedURL(
                bucket: bucketName, key: file.key, config: config)
            isLoadingImage = false

            // 加载图片尺寸信息
            await loadImageDimensions()
        } catch {
            imageLoadError = error
            isLoadingImage = false
        }
    }

    @MainActor
    private func loadImageDimensions() async {
        guard let imageURL = imageURL else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)

            // 使用 NSImage 获取图片尺寸
            if let nsImage = NSImage(data: data) {
                let dimensions = CGSize(width: nsImage.size.width, height: nsImage.size.height)
                imageDimensions = dimensions
            }
        } catch {
            // 如果获取尺寸失败，不影响图片显示，只是不显示尺寸信息
            print("Failed to load image dimensions: \(error)")
        }
    }

    // 判断是否应该显示实际尺寸
    private func shouldShowActualSize(dimensions: CGSize, containerSize: CGSize) -> Bool {
        // 减去信息栏高度（约 40 像素）和一些边距
        let availableHeight = containerSize.height - 80
        let availableWidth = containerSize.width - 40

        // 如果图片明显小于可用空间，显示实际尺寸
        // 使用 80% 作为阈值，避免图片几乎填满屏幕时还显示原始尺寸
        return dimensions.width <= availableWidth * 0.8 && dimensions.height <= availableHeight * 0.8
    }
}