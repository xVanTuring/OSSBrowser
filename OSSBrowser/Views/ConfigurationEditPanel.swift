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
                        Image(systemName: "network")
                            .font(.system(size: 14))
                        Text("测试连接")
                            .font(.system(size: 14))
                    }
                }
                .disabled(accessKeyId.isEmpty || accessKeySecret.isEmpty)
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

                        TextField("配置名称", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: name) { _ in markHasChanged() }
                    }

                    // 凭证信息
                    Group {
                        Text("凭证信息")
                            .font(.headline)

                        VStack(spacing: 12) {
                            TextField("Access Key ID", text: $accessKeyId)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: accessKeyId) { _ in markHasChanged() }

                            SecureField("Access Key Secret", text: $accessKeySecret)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: accessKeySecret) { _ in markHasChanged() }
                        }
                    }

                    // 区域设置
                    Group {
                        Text("区域设置")
                            .font(.headline)

                        Picker("Region", selection: $region) {
                            Text("华东1（杭州）").tag("cn-hangzhou")
                            Text("华东2（上海）").tag("cn-shanghai")
                            Text("华北1（青岛）").tag("cn-qingdao")
                            Text("华北2（北京）").tag("cn-beijing")
                            Text("华北3（张家口）").tag("cn-zhangjiakou")
                            Text("华北5（呼和浩特）").tag("cn-huhehaote")
                            Text("华南1（深圳）").tag("cn-shenzhen")
                            Text("西南1（成都）").tag("cn-chengdu")
                            Text("中国香港").tag("cn-hongkong")
                            Text("美国西部1（硅谷）").tag("us-west-1")
                            Text("美国东部1（弗吉尼亚）").tag("us-east-1")
                            Text("新加坡").tag("ap-southeast-1")
                            Text("日本（东京）").tag("ap-northeast-1")
                            Text("德国（法兰克福）").tag("eu-central-1")
                            Text("英国（伦敦）").tag("eu-west-1")
                            Text("澳大利亚（悉尼）").tag("ap-southeast-2")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: region) { _ in markHasChanged() }

                        Toggle("使用自定义 Endpoint", isOn: $useCustomEndpoint)
                            .onChange(of: useCustomEndpoint) { _ in markHasChanged() }

                        if useCustomEndpoint {
                            TextField("Endpoint", text: $endpoint)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: endpoint) { _ in markHasChanged() }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // 底部按钮
            HStack {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                if !isCreatingNew && hasChanges {
                    Button("重置") {
                        resetToOriginal()
                    }
                }

                Spacer()

                Button("保存") {
                    saveConfiguration()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || accessKeyId.isEmpty || accessKeySecret.isEmpty || (!hasChanges && !isCreatingNew))
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .alert("测试结果", isPresented: $showingTestAlert) {
            Button("确定") { }
        } message: {
            Text(testResult)
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

        Task {
            do {
                let ossService = OSSService()
                try await ossService.connect(with: testConfig)

                await MainActor.run {
                    testResult = "✅ 连接成功！"
                    showingTestAlert = true
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ 连接失败：\(error.localizedDescription)"
                    showingTestAlert = true
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