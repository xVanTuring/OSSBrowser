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

    @State private var loadedImage: NSImage?
    @State private var isLoadingImage = false
    @State private var imageLoadError: Error?
    @State private var shouldLoadLargeImage = false
    @State private var imageDimensions: CGSize?

    // 图片大小阈值：20MB（超过则不自动加载，先给出提示，避免大图长时间空转无反馈）
    private let imageThreshold: Int64 = 20 * 1024 * 1024

    var body: some View {
        VStack(spacing: 0) {
            // 主内容区域
            ZStack {
                if let loadedImage {
                    ZoomableImageView(
                        image: Image(nsImage: loadedImage),
                        pixelSize: imageDimensions ?? loadedImage.size,
                        showsCheckerboard: showsCheckerboard
                    )
                } else if file.size > imageThreshold && !shouldLoadLargeImage {
                    // 大图片提示
                    largeImagePrompt
                } else if isLoadingImage {
                    loadingView
                } else if let error = imageLoadError {
                    errorView(error: error)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 图片信息栏 - 始终显示
            infoBar
        }
        .onAppear {
            if file.size <= imageThreshold {
                loadPreviewImage()
            }
        }
    }

    // MARK: - 子视图

    private var infoBar: some View {
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

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.3)
            Text("正在加载…")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            Button {
                shouldLoadLargeImage = true
                loadPreviewImage()
            } label: {
                if isLoadingImage {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("加载中…")
                    }
                } else {
                    Label("加载图片", systemImage: "arrow.down.circle")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoadingImage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(error: Error) -> some View {
        // 复用通用提示视图，保证与其它预览视觉一致，并提供「重试」
        PreviewMessageView(
            systemImage: "exclamationmark.triangle",
            title: "加载失败",
            subtitle: error.localizedDescription,
            tint: .orange,
            primaryActionTitle: "重试",
            primaryAction: { loadPreviewImage() }
        )
    }

    // MARK: - 逻辑

    // 可能包含透明区域的格式，显示棋盘格背景便于分辨透明区域
    private var showsCheckerboard: Bool {
        let transparent = ["png", "gif", "svg", "webp", "tiff", "tif", "ico", "heic", "heif"]
        return transparent.contains((file.name as NSString).pathExtension.lowercased())
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
        loadedImage = nil
        imageDimensions = nil // 重置尺寸信息

        Task {
            await loadImageContent()
        }
    }

    @MainActor
    private func loadImageContent() async {
        do {
            let url = try await OSSPresigner.presignedURL(
                bucket: bucketName, key: file.key, config: config)
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let nsImage = NSImage(data: data) else {
                throw NSError(
                    domain: "ImagePreview", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "无法解析图片内容"])
            }

            imageDimensions = nsImage.size
            loadedImage = nsImage
            isLoadingImage = false
        } catch {
            imageLoadError = error
            isLoadingImage = false
        }
    }
}
