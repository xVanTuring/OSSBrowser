//
//  OSSBrowserApp.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI
import Combine

@main
struct OSSBrowserApp: App {
    @StateObject private var configManager = ConfigurationManager()

    var body: some Scene {
        // 配置管理窗口
        WindowGroup("配置管理") {
            ConfigurationListView()
                .environmentObject(configManager)
        }

        // OSS 浏览器窗口 - 支持多个实例
        WindowGroup(for: OSSConfiguration.self) { $config in
            if let config = config {
                OSSBrowserContentView(config: config, ossService: OSSService())
                    .frame(minWidth: 900, minHeight: 600)
            } else {
                Text("请从配置管理窗口打开 OSS 浏览器")
                    .foregroundColor(.secondary)
                    .frame(minWidth: 900, minHeight: 600)
            }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
        .handlesExternalEvents(matching: ["oss-browser"])
    }
}
