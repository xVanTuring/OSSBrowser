//
//  ConfigImportRequests.swift
//  OSSBrowser
//
//  双击 / 用 OSSBrowser 打开 .ossconfig 文件时，由 AppDelegate 收到文件地址，
//  放到这里并打开启动窗口；启动窗口取走地址后走正常的导入流程（输入密码 → 合并）。
//

import SwiftUI
import AppKit
import Combine

@MainActor
final class ConfigImportRequests: ObservableObject {
    static let shared = ConfigImportRequests()

    /// 等待启动窗口处理的文件
    @Published var pendingURL: URL?

    /// 打开（或切到前台）启动窗口；由任一窗口的视图注册，App 本身拿不到 openWindow
    var openLauncher: (() -> Void)?

    static let launcherWindowID = "launcher"

    func request(_ url: URL) {
        pendingURL = url
        openLauncher?()
        NSApp.activate()
    }
}

/// 应用代理：接收系统交给 App 打开的文件
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        // 一次只处理一个文件；多选打开时取第一个 .ossconfig
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == ConfigurationArchive.fileExtension }) else {
            return
        }
        MainActor.assumeIsolated {
            ConfigImportRequests.shared.request(url)
        }
    }
}

/// 在视图出现时注册「打开启动窗口」的方法
struct RegistersLauncherOpener: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            ConfigImportRequests.shared.openLauncher = {
                openWindow(id: ConfigImportRequests.launcherWindowID)
            }
        }
    }
}

extension View {
    func registersLauncherOpener() -> some View {
        modifier(RegistersLauncherOpener())
    }
}
