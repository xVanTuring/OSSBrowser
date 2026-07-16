//
//  SettingsView.swift
//  OSSBrowser
//
//  应用偏好设置（⌘,）。预览方式等全局设置放在这里，
//  通过 @AppStorage 持久化并与浏览界面共享。
//

import SwiftUI

enum PreviewSettings {
    /// 预览方式：true = 系统 QuickLook，false = 内置预览
    static let useQuickLookKey = "useQuickLookPreview"
}

struct SettingsView: View {
    @AppStorage(PreviewSettings.useQuickLookKey) private var useQuickLook: Bool = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("预览", systemImage: "eye") }
        }
        .frame(width: 460, height: 220)
    }

    private var generalTab: some View {
        Form {
            Picker("文件预览方式", selection: $useQuickLook) {
                Text("内置预览").tag(false)
                Text("系统 QuickLook").tag(true)
            }
            .pickerStyle(.radioGroup)

            Text(useQuickLook
                 ? "使用系统 QuickLook 预览：原生支持视频、PDF、音频、文本等更多类型。"
                 : "使用内置预览窗口：支持图片、视频、音频、PDF、文本。")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
    }
}

#Preview {
    SettingsView()
}
