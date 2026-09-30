//
//  ConfigurationListView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//
//  启动窗口：左侧应用信息 + 新建配置，右侧配置列表（编辑 / 打开）。
//  新建与编辑在弹出窗口中进行。
//

import SwiftUI

/// 弹出编辑窗口的目标；每次生成新 id，保证重复编辑同一配置也会重建表单
private struct EditTarget: Identifiable {
    let id = UUID()
    let config: OSSConfiguration
    let isCreatingNew: Bool
}

struct ConfigurationListView: View {
    @StateObject private var configManager = ConfigurationManager()
    @Environment(\.openWindow) private var openWindow
    @State private var editTarget: EditTarget?
    @State private var configToDelete: OSSConfiguration?

    var body: some View {
        HStack(spacing: 0) {
            LauncherSidebar(onNewConfiguration: addNewConfiguration)

            Divider()

            configurationList
        }
        .sheet(item: $editTarget) { target in
            ConfigurationEditPanel(
                config: target.config,
                isCreatingNew: target.isCreatingNew,
                onSave: { saved in
                    if target.isCreatingNew {
                        configManager.addConfiguration(saved)
                    } else {
                        configManager.updateConfiguration(saved)
                    }
                    editTarget = nil
                },
                onCancel: { editTarget = nil }
            )
        }
        .alert(
            "删除配置",
            isPresented: Binding(
                get: { configToDelete != nil },
                set: { if !$0 { configToDelete = nil } }
            ),
            presenting: configToDelete
        ) { config in
            Button("删除", role: .destructive) {
                configManager.deleteConfiguration(config)
            }
            Button("取消", role: .cancel) {}
        } message: { config in
            Text("确定要删除配置 \"\(config.name)\" 吗？此操作无法撤销。")
        }
        // 首页固定尺寸，禁止拖拽调整大小与全屏
        .frame(width: 760, height: 540)
        .fixedSizeWindow()
    }

    // MARK: - 右侧配置列表

    private var configurationList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("配置")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                if !configManager.configurations.isEmpty {
                    Text("\(configManager.configurations.count)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 12)

            if configManager.configurations.isEmpty {
                ContentUnavailableView {
                    Label("还没有配置", systemImage: "externaldrive.badge.plus")
                } description: {
                    Text("创建一个 OSS 配置，即可开始浏览你的 Bucket。")
                } actions: {
                    Button {
                        addNewConfiguration()
                    } label: {
                        Label("新建配置", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(configManager.configurations, id: \.id) { config in
                            ConfigurationRow(
                                config: config,
                                onEdit: { editTarget = EditTarget(config: config, isCreatingNew: false) },
                                onOpen: { openWindow(value: config) },
                                onDuplicate: { _ = configManager.duplicateConfiguration(config) },
                                onDelete: { configToDelete = config }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addNewConfiguration() {
        editTarget = EditTarget(
            config: OSSConfiguration(name: "", accessKeyId: "", accessKeySecret: "", region: "cn-hangzhou"),
            isCreatingNew: true
        )
    }
}

#Preview {
    ConfigurationListView()
}
