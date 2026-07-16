//
//  TextPreview.swift
//  OSSBrowser
//
//  文本/代码预览：通过 Range 请求只拉取文件头部，避免大文件全量下载。
//

import SwiftUI

struct TextPreview: View {
    let file: OSSFile
    let bucketName: String
    let config: OSSConfiguration

    @State private var content: String?
    @State private var isLoading = true
    @State private var loadError: Error?
    // 自动换行：默认对非代码文本换行，代码保持原样便于对齐
    @State private var wrapLines: Bool
    @State private var fontSize: CGFloat = 13

    // 最多预览 512KB
    private let maxBytes = 512 * 1024

    // 保持对外初始化签名不变（file / bucketName / config），
    // 仅用于根据文件类型设置换行默认值。
    init(file: OSSFile, bucketName: String, config: OSSConfiguration) {
        self.file = file
        self.bucketName = bucketName
        self.config = config
        _wrapLines = State(initialValue: file.category != .code)
    }

    private var isTruncated: Bool {
        file.size > Int64(maxBytes)
    }

    private var textFont: Font {
        .system(size: fontSize, design: .monospaced)
    }

    var body: some View {
        Group {
            if let content = content {
                VStack(spacing: 0) {
                    toolbar
                    Divider()

                    textScrollView(content)

                    if isTruncated {
                        Divider()
                        Text("内容较大，仅预览前 \(ByteCountFormatter.string(fromByteCount: Int64(maxBytes), countStyle: .file))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                    }
                }
            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.3)
                    Text("正在加载…")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError = loadError {
                PreviewMessageView(
                    systemImage: "exclamationmark.triangle",
                    title: "加载失败",
                    subtitle: loadError.localizedDescription,
                    tint: .orange,
                    primaryActionTitle: "重试",
                    primaryAction: { retry() }
                )
            }
        }
        .task { await load() }
    }

    // MARK: - 子视图

    private var toolbar: some View {
        HStack(spacing: 10) {
            Toggle("自动换行", isOn: $wrapLines)
                .toggleStyle(.switch)
                .controlSize(.small)

            Spacer()

            // 字号调节
            Button {
                fontSize = max(9, fontSize - 1)
            } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .help("减小字号")

            Text("\(Int(fontSize))")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 20)

            Button {
                fontSize = min(24, fontSize + 1)
            } label: {
                Image(systemName: "textformat.size.larger")
            }
            .help("增大字号")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private func textScrollView(_ content: String) -> some View {
        if wrapLines {
            // 换行：仅纵向滚动，长段落自动折行
            ScrollView(.vertical) {
                Text(content)
                    .font(textFont)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        } else {
            // 不换行：横竖双向滚动，保持长行原样
            ScrollView([.vertical, .horizontal]) {
                Text(content)
                    .font(textFont)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
    }

    // MARK: - 逻辑

    /// 重新触发加载
    private func retry() {
        content = nil
        loadError = nil
        isLoading = true
        Task { await load() }
    }

    private func load() async {
        do {
            let url = try await OSSPresigner.presignedURL(
                bucket: bucketName, key: file.key, config: config)

            var request = URLRequest(url: url)
            if isTruncated {
                request.setValue("bytes=0-\(maxBytes - 1)", forHTTPHeaderField: "Range")
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            let text = String(data: data, encoding: .utf8)
                ?? String(decoding: data, as: UTF8.self)

            await MainActor.run {
                self.content = text
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = error
                self.isLoading = false
            }
        }
    }
}
