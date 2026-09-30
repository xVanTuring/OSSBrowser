//
//  LauncherSidebar.swift
//  OSSBrowser
//
//  启动窗口左侧：应用图标、名称、版本号，以及新建配置 / 新建分组 / 导入 / 导出按钮。
//

import SwiftUI
import AppKit

struct LauncherSidebar: View {
    let onNewConfiguration: () -> Void
    let onNewGroup: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void
    /// 没有配置时禁用导出
    let canExport: Bool

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "版本 \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                // 图标下方的暖色光晕，呼应图标底色
                .shadow(color: Color(red: 0.95, green: 0.35, blue: 0.3).opacity(0.45), radius: 24, y: 6)
                .padding(.top, 64)

            Text("OSSBrowser")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 16)
            Text(versionText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Spacer()

            VStack(spacing: 10) {
                Button(action: onNewConfiguration) {
                    Label("新建配置…", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button(action: onNewGroup) {
                    Label("新建分组…", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 10) {
                    Button(action: onImport) {
                        Label("导入", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    Button(action: onExport) {
                        Label("导出", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canExport)
                }
            }
            .controlSize(.large)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(width: 250)
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.03))
    }
}
