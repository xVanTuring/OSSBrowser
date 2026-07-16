//
//  PreviewMessageView.swift
//  OSSBrowser
//
//  预览区域通用的居中提示（加载失败、格式不支持等）。
//

import SwiftUI

struct PreviewMessageView: View {
    let systemImage: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = .secondary

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundColor(tint)

            Text(title)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
