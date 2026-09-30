//
//  LauncherSidebar.swift
//  OSSBrowser
//
//  启动窗口左侧：应用图标、名称、版本号，以及「新建配置」按钮。
//

import SwiftUI
import AppKit

struct LauncherSidebar: View {
    let onNewConfiguration: () -> Void

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "版本 \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                // 图标下方的暖色光晕，呼应图标底色
                .shadow(color: Color(red: 0.95, green: 0.35, blue: 0.3).opacity(0.45), radius: 24, y: 6)

            Text("OSSBrowser")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 16)
            Text(versionText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Spacer()

            Button(action: onNewConfiguration) {
                Label("新建配置…", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(width: 250)
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.03))
    }
}
