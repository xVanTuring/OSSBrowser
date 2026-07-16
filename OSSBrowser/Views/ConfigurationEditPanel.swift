//
//  ConfigurationEditPanel.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI

struct ConfigurationEditPanel: View {
    let config: OSSConfiguration
    let isCreatingNew: Bool
    let onSave: (OSSConfiguration) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var accessKeyId: String = ""
    @State private var accessKeySecret: String = ""
    @State private var region: String = "cn-hangzhou"
    @State private var endpoint: String = ""
    @State private var useCustomEndpoint: Bool = false
    @State private var showingTestAlert = false
    @State private var testResult: String = ""
    @State private var hasChanges = false
    @State private var isTesting = false          // 测试连接进行中
    @State private var isSecretVisible = false     // 是否明文显示 AccessKeySecret
    @State private var showSaveSuccess = false     // 保存成功的短暂反馈

    // 新建时让初始焦点落到「配置名称」字段
    @FocusState private var isNameFocused: Bool

    init(config: OSSConfiguration, isCreatingNew: Bool, onSave: @escaping (OSSConfiguration) -> Void, onCancel: @escaping () -> Void) {
        self.config = config
        self.isCreatingNew = isCreatingNew
        self.onSave = onSave
        self.onCancel = onCancel

        // 初始化状态
        if isCreatingNew {
            _name = State(initialValue: "")
            _accessKeyId = State(initialValue: "")
            _accessKeySecret = State(initialValue: "")
            _region = State(initialValue: "cn-hangzhou")
            _endpoint = State(initialValue: "")
            _useCustomEndpoint = State(initialValue: false)
        } else {
            _name = State(initialValue: config.name)
            _accessKeyId = State(initialValue: config.accessKeyId)
            _accessKeySecret = State(initialValue: config.accessKeySecret)
            _region = State(initialValue: config.region)
            _endpoint = State(initialValue: config.endpoint ?? "")
            _useCustomEndpoint = State(initialValue: config.endpoint != nil)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(isCreatingNew ? "新建配置" : "查看/编辑配置")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // 测试连接按钮
                Button(action: testConnection) {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "network")
                                .font(.system(size: 14))
                        }
                        Text(isTesting ? "测试中…" : "测试连接")
                            .font(.system(size: 14))
                    }
                }
                .disabled(accessKeyId.isEmpty || accessKeySecret.isEmpty || isTesting)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 基本信息
                    Group {
                        Text("基本信息")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 4) {
                            requiredFieldLabel("配置名称")
                            TextField("例如：我的生产环境", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .focused($isNameFocused)
                                .onChange(of: name) { markHasChanged() }
                        }
                    }

                    // 凭证信息
                    Group {
                        Text("凭证信息")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                requiredFieldLabel("Access Key ID")
                                TextField("Access Key ID", text: $accessKeyId)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: accessKeyId) { markHasChanged() }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                requiredFieldLabel("Access Key Secret")
                                HStack(spacing: 8) {
                                    // 眼睛按钮切换明文/密文显示
                                    Group {
                                        if isSecretVisible {
                                            TextField("Access Key Secret", text: $accessKeySecret)
                                        } else {
                                            SecureField("Access Key Secret", text: $accessKeySecret)
                                        }
                                    }
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: accessKeySecret) { markHasChanged() }

                                    Button {
                                        isSecretVisible.toggle()
                                    } label: {
                                        Image(systemName: isSecretVisible ? "eye.slash" : "eye")
                                    }
                                    .buttonStyle(.borderless)
                                    .help(isSecretVisible ? "隐藏" : "显示")
                                }
                            }
                        }
                    }

                    // 区域设置
                    Group {
                        Text("区域设置")
                            .font(.headline)

                        OSSRegionPicker(title: "Region", selection: $region)
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onChange(of: region) { markHasChanged() }

                        Toggle("使用自定义 Endpoint", isOn: $useCustomEndpoint)
                            .onChange(of: useCustomEndpoint) { markHasChanged() }

                        if useCustomEndpoint {
                            TextField("https://oss-cn-hangzhou.aliyuncs.com", text: $endpoint)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: endpoint) { markHasChanged() }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // 底部按钮
            HStack(spacing: 12) {
                // 新建模式：保留「取消」（Esc）；
                // 编辑模式：隐藏「取消」，仅在有更改时出现「重置」（Esc 等同重置），避免无意义的空操作。
                if isCreatingNew {
                    Button("取消") {
                        onCancel()
                    }
                    .keyboardShortcut(.escape)
                } else if hasChanges {
                    Button("重置") {
                        resetToOriginal()
                    }
                    .keyboardShortcut(.escape)
                }

                // 必填缺失时提示原因，解释「保存」为何禁用
                if let missing = missingRequiredFieldsMessage {
                    Label(missing, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()

                // 保存成功的短暂反馈
                if showSaveSuccess {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                Button("保存") {
                    saveConfiguration()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .onAppear {
            // 新建时把初始焦点放到「配置名称」
            if isCreatingNew {
                DispatchQueue.main.async {
                    isNameFocused = true
                }
            }
        }
        .alert("测试结果", isPresented: $showingTestAlert) {
            Button("确定") { }
        } message: {
            Text(testResult)
        }
    }

    /// 必填字段是否齐全，且（编辑态）确有改动
    private var canSave: Bool {
        !name.isEmpty && !accessKeyId.isEmpty && !accessKeySecret.isEmpty
            && (hasChanges || isCreatingNew)
    }

    /// 缺失的必填字段提示；无缺失返回 nil
    private var missingRequiredFieldsMessage: String? {
        var fields: [String] = []
        if name.isEmpty { fields.append("配置名称") }
        if accessKeyId.isEmpty { fields.append("Access Key ID") }
        if accessKeySecret.isEmpty { fields.append("Access Key Secret") }
        guard !fields.isEmpty else { return nil }
        return "请填写：" + fields.joined(separator: "、")
    }

    /// 必填字段标签：名称后附红色 * 号
    private func requiredFieldLabel(_ text: String) -> some View {
        HStack(spacing: 2) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("*")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }

    private func markHasChanged() {
        hasChanges = true
    }

    private func resetToOriginal() {
        name = config.name
        accessKeyId = config.accessKeyId
        accessKeySecret = config.accessKeySecret
        region = config.region
        if let endpoint = config.endpoint {
            self.endpoint = endpoint
            useCustomEndpoint = true
        } else {
            endpoint = ""
            useCustomEndpoint = false
        }
        hasChanges = false
    }

    private func testConnection() {
        let endpoint = useCustomEndpoint ? (endpoint.isEmpty ? nil : endpoint) : nil
        let testConfig = OSSConfiguration(
            name: name,
            accessKeyId: accessKeyId,
            accessKeySecret: accessKeySecret,
            region: region,
            endpoint: endpoint
        )

        isTesting = true
        Task {
            do {
                let ossService = OSSService()
                try await ossService.connect(with: testConfig)
                let buckets = try await ossService.listBuckets()

                await MainActor.run {
                    testResult = "✅ 连接成功！可访问 \(buckets.count) 个 Bucket。"
                    showingTestAlert = true
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ 连接失败：\(OSSFriendlyError.message(for: error))"
                    showingTestAlert = true
                    isTesting = false
                }
            }
        }
    }

    private func saveConfiguration() {
        let endpoint = useCustomEndpoint ? (endpoint.isEmpty ? nil : endpoint) : nil

        // 创建新配置但保留原有 ID
        var newConfig = OSSConfiguration(
            name: name,
            accessKeyId: accessKeyId,
            accessKeySecret: accessKeySecret,
            region: region,
            endpoint: endpoint
        )

        // 如果是编辑模式，保留原有的 ID
        if !isCreatingNew {
            newConfig = OSSConfiguration(
                id: config.id,
                name: name,
                accessKeyId: accessKeyId,
                accessKeySecret: accessKeySecret,
                region: region,
                endpoint: endpoint
            )
        }

        onSave(newConfig)

        // 保存成功闭环：复位 hasChanges（置灰保存按钮）并给出短暂成功反馈
        hasChanges = false
        withAnimation { showSaveSuccess = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation { showSaveSuccess = false }
            }
        }
    }
}

#Preview {
    ConfigurationEditPanel(
        config: OSSConfiguration(
            name: "Test Config",
            accessKeyId: "",
            accessKeySecret: "",
            region: "cn-hangzhou"
        ),
        isCreatingNew: true,
        onSave: { _ in },
        onCancel: { }
    )
}
