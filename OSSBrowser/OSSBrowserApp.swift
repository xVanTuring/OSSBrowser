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
        // 配置管理窗口（首页）：固定尺寸
        WindowGroup("配置管理") {
            ConfigurationListView()
                .environmentObject(configManager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 540)

        // OSS 浏览器窗口 - 支持多个实例
        WindowGroup(for: OSSConfiguration.self) { $config in
            if let config = config {
                OSSBrowserContentView(config: config, ossService: OSSService())
            } else {
                Text("请从配置管理窗口打开 OSS 浏览器")
                    .foregroundColor(.secondary)
            }
        }
        
        // 不限制尺寸，自由拖拽缩放
        .windowResizability(.automatic)
        .defaultSize(width: 1280, height: 800)
        .handlesExternalEvents(matching: ["oss-browser"])

        // 应用偏好设置（⌘,）
        Settings {
            SettingsView()
        }
    }
}
