//
//  NewFolderInlineRow.swift
//  OSSBrowser
//
//  Finder 风格的内联「新建文件夹」行：在文件列表顶部出现一行可编辑输入，
//  回车确认、Esc 取消，并即时校验非法字符与重名。
//

import SwiftUI

struct NewFolderInlineRow: View {
    /// 当前目录下已存在的文件夹名（小写，用于重名校验）
    let existingNames: Set<String>
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @FocusState private var focused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    /// 非空但非法时的错误提示
    private var validationError: String? {
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("/") { return "名称不能包含 “/”" }
        if trimmed == "." || trimmed == ".." { return "无效的名称" }
        if existingNames.contains(trimmed.lowercased()) { return "已存在同名文件夹" }
        return nil
    }

    private var canCommit: Bool {
        !trimmed.isEmpty && validationError == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                    .frame(width: 16, height: 16)

                TextField("新建文件夹", text: $name)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { commit() }
                    .onExitCommand { onCancel() }

                if let validationError = validationError {
                    Label(validationError, systemImage: "exclamationmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize()
                }

                Spacer(minLength: 8)

                Button("取消") { onCancel() }
                    .controlSize(.small)
                Button("创建") { commit() }
                    .controlSize(.small)
                    .disabled(!canCommit)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.10))

            Divider()
        }
        .onAppear {
            // 稍作延迟确保 TextField 已进入视图层级后再抢焦点
            DispatchQueue.main.async { focused = true }
        }
    }

    private func commit() {
        guard canCommit else { return }
        onCommit(trimmed)
    }
}
