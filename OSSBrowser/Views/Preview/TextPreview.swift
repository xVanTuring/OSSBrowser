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

    // 最多预览 512KB
    private let maxBytes = 512 * 1024

    private var isTruncated: Bool {
        file.size > Int64(maxBytes)
    }

    var body: some View {
        Group {
            if let content = content {
                VStack(spacing: 0) {
                    ScrollView([.vertical, .horizontal]) {
                        Text(content)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }

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
                    tint: .orange
                )
            }
        }
        .task { await load() }
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
