//
//  WindowConfigurator.swift
//  OSSBrowser
//
//  通过桥接 AppKit 配置所在的 NSWindow（SwiftIU 未提供禁用缩放/全屏的公开 API）。
//

import SwiftUI
import AppKit

private struct WindowConfigurator: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        apply(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        apply(from: nsView)
    }

    private func apply(from view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configure(window)
        }
    }
}

extension View {
    /// 访问并配置所在窗口的 NSWindow
    func configureWindow(_ configure: @escaping (NSWindow) -> Void) -> some View {
        background(WindowConfigurator(configure: configure).frame(width: 0, height: 0))
    }

    /// 固定窗口：禁止拖拽调整大小，禁止进入全屏，禁用缩放按钮
    func fixedSizeWindow() -> some View {
        configureWindow { window in
            window.styleMask.remove(.resizable)
            window.collectionBehavior.remove(.fullScreenPrimary)
            window.collectionBehavior.insert(.fullScreenNone)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }
    }
}
