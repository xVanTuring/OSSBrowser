//
//  ConfigurationListView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI

struct ConfigurationListView: View {
    @StateObject private var configManager = ConfigurationManager()
    @Environment(\.openWindow) private var openWindow
    @State private var selectedConfig: OSSConfiguration?
    @State private var editingConfig: OSSConfiguration?
    @State private var isCreatingNew = false
    @State private var showingDeleteAlert = false
    @State private var configToDelete: OSSConfiguration?

    var body: some View {
        NavigationSplitView {
            // 左侧配置列表
            List(configManager.configurations, id: \.id, selection: $selectedConfig) { config in
                HStack(spacing: 12) {
                    Image(systemName: "externaldrive.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(config.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(config.region)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 8)

                    Button {
                        openBrowser(for: config)
                    } label: {
                        Image(systemName: "arrow.up.forward")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("打开 OSS 浏览器")
                }
                .padding(.vertical, 2)
                .contextMenu {
                    Button {
                        openBrowser(for: config)
                    } label: {
                        Label("打开", systemImage: "arrow.up.forward")
                    }
                    Button {
                        selectedConfig = configManager.duplicateConfiguration(config)
                    } label: {
                        Label("复制配置", systemImage: "plus.square.on.square")
                    }
                    Divider()
                    Button(role: .destructive) {
                        configToDelete = config
                        showingDeleteAlert = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .tag(config)
            }
            .navigationTitle("OSS 配置")
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { addNewConfiguration() }) {
                        Image(systemName: "plus")
                    }
                    .help("添加配置")

                    Button(action: { duplicateSelectedConfiguration() }) {
                        Image(systemName: "plus.square.on.square")
                    }
                    .disabled(selectedConfig == nil)
                    .help("复制配置")

                    Button(action: { deleteSelectedConfiguration() }) {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedConfig == nil)
                    .help("删除配置")
                }
            }
            .onDeleteCommand(perform: deleteSelectedConfiguration)
        } detail: {
            // 右侧编辑面板
            if isCreatingNew {
                // 新建模式
                ConfigurationEditPanel(
                    config: OSSConfiguration(
                        name: "",
                        accessKeyId: "",
                        accessKeySecret: "",
                        region: "cn-hangzhou"
                    ),
                    isCreatingNew: true,
                    onSave: { newConfig in
                        configManager.addConfiguration(newConfig)
                        selectedConfig = newConfig
                        isCreatingNew = false
                    },
                    onCancel: {
                        isCreatingNew = false
                        selectedConfig = nil
                    }
                )
            } else if selectedConfig != nil {
                // 查看/编辑模式
                ConfigurationEditPanel(
                    config: selectedConfig!,
                    isCreatingNew: false,
                    onSave: { updatedConfig in
                        configManager.updateConfiguration(updatedConfig)
                        selectedConfig = updatedConfig
                    },
                    onCancel: {
                        // 不做任何事，只是保持选中状态
                    }
                )
                .id(selectedConfig?.id)  // 添加 id 以确保在切换配置时重新创建视图
            } else {
                // 空状态
                VStack(spacing: 20) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("选择一个配置进行编辑")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text("或点击右上角的 + 按钮创建新配置")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("删除配置", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                if let config = configToDelete {
                    configManager.deleteConfiguration(config)
                    if selectedConfig?.id == config.id {
                        selectedConfig = nil
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let config = configToDelete {
                Text("确定要删除配置 \"\(config.name)\" 吗？此操作无法撤销。")
            }
        }
        // 首页固定尺寸，禁止拖拽调整大小与全屏
        .frame(width: 760, height: 540)
        .fixedSizeWindow()
    }

    private func addNewConfiguration() {
        editingConfig = nil
        isCreatingNew = true
        selectedConfig = nil
    }

    private func deleteSelectedConfiguration() {
        if let config = selectedConfig {
            configToDelete = config
            showingDeleteAlert = true
        }
    }

    private func openBrowser(for config: OSSConfiguration) {
        // 使用 SwiftUI 的 openWindow API 打开浏览器窗口
        selectedConfig = config
        openWindow(value: config)
    }

    private func duplicateSelectedConfiguration() {
        guard let config = selectedConfig else { return }
        let copy = configManager.duplicateConfiguration(config)
        selectedConfig = copy
    }
}

#Preview {
    ConfigurationListView()
}
