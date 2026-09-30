//
//  PasswordPromptSheet.swift
//  OSSBrowser
//
//  导入导出配置时输入密码。导出需要再次输入确认；导入只输入一次。
//

import SwiftUI

struct PasswordPromptSheet: View {
    let title: String
    let message: String
    /// 是否需要再次输入确认（导出时）
    let requiresConfirmation: Bool
    let confirmTitle: String
    /// 由调用方填入的错误信息（如导入时密码错误），显示在输入框下方
    var errorMessage: String? = nil
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var password = ""
    @State private var confirmation = ""
    @FocusState private var isPasswordFocused: Bool

    private static let minimumLength = 6

    /// 本地校验提示；无问题返回 nil
    private var validationMessage: String? {
        guard requiresConfirmation else { return nil }
        if !password.isEmpty && password.count < Self.minimumLength {
            return "密码至少 \(Self.minimumLength) 位"
        }
        if !confirmation.isEmpty && confirmation != password {
            return "两次输入的密码不一致"
        }
        return nil
    }

    private var canSubmit: Bool {
        if requiresConfirmation {
            return password.count >= Self.minimumLength && password == confirmation
        }
        return !password.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                SecureField("密码", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .focused($isPasswordFocused)
                    .onSubmit(submit)
                if requiresConfirmation {
                    SecureField("再次输入密码", text: $confirmation)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(submit)
                }
                if let message = validationMessage ?? errorMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle, action: submit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear {
            DispatchQueue.main.async { isPasswordFocused = true }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        onSubmit(password)
    }
}
