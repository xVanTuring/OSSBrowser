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
    @State private var isLoading = true
    @State private var loadError: Error?

    var body: some View {
        Group {
            if let document = document {
                PDFKitRepresentedView(document: document)
            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.3)
                    Text("正在加载 PDF…")
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
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let doc = PDFDocument(data: data) else {
                throw NSError(
                    domain: "PDFPreview", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "无法解析 PDF 内容"])
            }
            await MainActor.run {
                self.document = doc
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
