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
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var configManager = ConfigurationManager()

    var body: some Scene {
        // 配置管理窗口（首页）：固定尺寸、隐藏标题栏的启动窗口。
        // 用单实例 Window，打开 .ossconfig 文件时切到前台而不是再开一个
        Window("配置管理", id: ConfigImportRequests.launcherWindowID) {
            ConfigurationListView()
                .environmentObject(configManager)
                .registersLauncherOpener()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 540)

        // OSS 浏览器窗口 - 支持多个实例
        WindowGroup(for: OSSConfiguration.self) { $config in
            if let config = config {
                OSSBrowserContentView(config: config, ossService: OSSService())
                    // 窗口标题设为配置名，便于多窗口区分
                    .navigationTitle(config.name)
                    // 启动窗口关闭后，打开 .ossconfig 文件仍能把它重新打开
                    .registersLauncherOpener()
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
