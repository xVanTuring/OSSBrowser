//
//  PDFPreview.swift
//  OSSBrowser
//
//  PDF 预览：下载预签名 URL 数据后用 PDFKit 渲染。
//

import SwiftUI
import PDFKit

struct PDFPreview: View {
    let file: OSSFile
    let bucketName: String
    let config: OSSConfiguration

    @State private var document: PDFDocument?
    @State private var loadError: Error?
    @State private var confirmedLargeLoad = false

    // 大 PDF 阈值：50MB（超过则加载前二次确认，避免长时间空转无反馈）
    private let sizeThreshold: Int64 = 50 * 1024 * 1024

    var body: some View {
        Group {
            if let document = document {
                PDFKitRepresentedView(document: document)
            } else if file.size > sizeThreshold && !confirmedLargeLoad {
                largeFilePrompt
            } else if let loadError = loadError {
                PreviewMessageView(
                    systemImage: "exclamationmark.triangle",
                    title: "加载失败",
                    subtitle: loadError.localizedDescription,
                    tint: .orange,
                    primaryActionTitle: "重试",
                    primaryAction: { startLoad() }
                )
            } else {
                loadingView
            }
        }
        .task {
            // 小文件自动加载；大文件等待用户确认
            if file.size <= sizeThreshold {
                startLoad()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.3)
            Text("正在加载 PDF…")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var largeFilePrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("大 PDF 文件")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("文件大小: \(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("加载较大的 PDF 可能需要一些时间")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                confirmedLargeLoad = true
                startLoad()
            } label: {
                Label("加载 PDF", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 重新触发加载（清空文档与错误后重新拉取）
    private func startLoad() {
        document = nil
        loadError = nil
        Task { await load() }
    }

    private func load() async {
        do {
            let url = try await OSSPresigner.presignedURL(
                bucket: bucketName, key: file.key, config: config)
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let doc = PDFDocument(data: data) else {
                throw NSError(
                    domain: "PDFPreview", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "无法解析 PDF 内容"])
            }
            await MainActor.run {
                self.document = doc
            }
        } catch {
            await MainActor.run {
                self.loadError = error
            }
        }
    }
}

private struct PDFKitRepresentedView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.document = document
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document !== document {
            nsView.document = document
        }
    }
}
