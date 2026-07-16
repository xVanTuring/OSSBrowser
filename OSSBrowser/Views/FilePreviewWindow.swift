//
//  FilePreviewWindow.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/14.
//

import SwiftUI
import AlibabaCloudOSS

struct FilePreviewWindow: View {
    let files: [OSSFile]
    let bucketName: String
    let config: OSSConfiguration
    @Environment(\.dismiss) private var dismiss

    @State private var index: Int
    @State private var hint: String?

    /// 传入被点击的文件与同目录可预览文件列表；若该文件不在列表中（如目录），则单独展示
    init(file: OSSFile, files: [OSSFile], bucketName: String, config: OSSConfiguration) {
        if let idx = files.firstIndex(where: { $0.id == file.id }) {
            self.files = files
            self._index = State(initialValue: idx)
        } else {
            self.files = [file]
            self._index = State(initialValue: 0)
        }
        self.bucketName = bucketName
        self.config = config
    }

    private var currentFile: OSSFile {
        files.indices.contains(index) ? files[index] : files[0]
    }

    private var canGoPrev: Bool { index > 0 }
    private var canGoNext: Bool { index < files.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            Divider()

            // 内容区域：按文件分类路由到对应预览
            Group {
                switch currentFile.previewKind {
                case .folder:
                    FolderPreview(file: currentFile)
                case .image:
                    ImagePreview(file: currentFile, bucketName: bucketName, config: config)
                case .video:
                    VideoPreview(file: currentFile, bucketName: bucketName, config: config)
                case .audio:
                    AudioPreview(file: currentFile, bucketName: bucketName, config: config)
                case .pdf:
                    PDFPreview(file: currentFile, bucketName: bucketName, config: config)
                case .text:
                    TextPreview(file: currentFile, bucketName: bucketName, config: config)
                case .none:
                    GenericFilePreview(file: currentFile)
                }
            }
            .id(currentFile.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(minWidth: 600, idealWidth: 720, minHeight: 500, idealHeight: 620)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { goPrev() }
        .onKeyPress(.rightArrow) { goNext() }
        .overlay(alignment: .bottom) {
            if let hint {
                Text(hint)
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.2)))
                    .shadow(radius: 10, y: 2)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: hint)
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            // 上一张 / 下一张
            if files.count > 1 {
                Button { _ = goPrev() } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .disabled(!canGoPrev)
                .help("上一张 (←)")

                Button { _ = goNext() } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(!canGoNext)
                .help("下一张 (→)")

                Text("\(index + 1) / \(files.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(currentFile.name)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(currentFile.name)

            Spacer(minLength: 8)

            Button(action: downloadCurrent) {
                Image(systemName: "arrow.down.circle")
            }
            .buttonStyle(.plain)
            .help("下载到「下载」文件夹")

            Button(action: copyLink) {
                Image(systemName: "link")
            }
            .buttonStyle(.plain)
            .help("复制预签名链接（10 分钟有效）")

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape)
            .help("关闭 (Esc)")
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Actions

    @discardableResult
    private func goPrev() -> KeyPress.Result {
        guard canGoPrev else { return .ignored }
        index -= 1
        return .handled
    }

    @discardableResult
    private func goNext() -> KeyPress.Result {
        guard canGoNext else { return .ignored }
        index += 1
        return .handled
    }

    private func downloadCurrent() {
        DownloadManager.shared.configure(with: config)
        DownloadManager.shared.downloadFile(currentFile, from: bucketName)
        showHint("已开始下载")
    }

    private func copyLink() {
        let file = currentFile
        Task {
            do {
                let urlString = try await OSSPresigner.presignedURLString(
                    bucket: bucketName, key: file.key, config: config, expiresIn: 600)
                await MainActor.run {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(urlString, forType: .string)
                    showHint("已复制链接（10 分钟有效）")
                }
            } catch {
                await MainActor.run { showHint("生成链接失败") }
            }
        }
    }

    private func showHint(_ text: String) {
        hint = text
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                if hint == text { hint = nil }
            }
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
        files: [
            OSSFile(key: "test.jpg", size: 1024 * 1024, lastModified: Date(), eTag: "", storageClass: "Standard", isDirectory: false)
        ],
        bucketName: "test-bucket",
        config: OSSConfiguration(
            name: "Test",
            accessKeyId: "",
            accessKeySecret: "",
            region: "cn-hangzhou"
        )
    )
}
