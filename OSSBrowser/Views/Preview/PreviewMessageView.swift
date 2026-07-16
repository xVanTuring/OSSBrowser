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

    // 可选操作按钮槽位（默认 nil，兼容现有调用）。
    // 主要按钮通常用于「重试」，次要按钮可用于「下载」等。
    var primaryActionTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryActionTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

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

            if primaryAction != nil || secondaryAction != nil {
                HStack(spacing: 12) {
                    if let title = primaryActionTitle, let action = primaryAction {
                        Button(title, action: action)
                            .buttonStyle(.borderedProminent)
                    }
                    if let title = secondaryActionTitle, let action = secondaryAction {
                        Button(title, action: action)
                            .buttonStyle(.bordered)
                    }
                }
                .controlSize(.large)
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
