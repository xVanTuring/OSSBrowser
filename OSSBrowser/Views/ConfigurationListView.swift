//
//  ConfigurationListView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//
//  启动窗口：左侧应用信息与操作按钮，右侧按分组显示的配置列表（编辑 / 打开）。
//  新建与编辑在弹出窗口中进行；导入导出的文件用密码加密。
//

import SwiftUI
import AppKit

/// 弹出编辑窗口的目标；每次生成新 id，保证重复编辑同一配置也会重建表单
private struct EditTarget: Identifiable {
    let id = UUID()
    let config: OSSConfiguration
    let isCreatingNew: Bool
}

/// 新建 / 重命名分组的输入框
private struct GroupNamePrompt: Identifiable {
    let id = UUID()
    /// nil 表示新建
    let groupId: UUID?
}

/// 输入密码的弹出窗口
private enum PasswordPrompt: Identifiable {
    case export
    case `import`(Data)

    var id: String {
        switch self {
        case .export: return "export"
        case .import: return "import"
        }
    }
}

struct ConfigurationListView: View {
    @StateObject private var configManager = ConfigurationManager()
    @Environment(\.openWindow) private var openWindow
    @State private var editTarget: EditTarget?
    @State private var configToDelete: OSSConfiguration?

    @State private var groupNamePrompt: GroupNamePrompt?
    @State private var groupNameText = ""
    @State private var groupToDelete: ConfigGroup?
    @State private var collapsedGroups: Set<UUID> = []

    @State private var passwordPrompt: PasswordPrompt?
    @State private var passwordError: String?
    /// 导入结果、导入导出失败等提示
    @State private var noticeMessage: String?

    /// 双击 .ossconfig 文件时传入的待导入文件
    @ObservedObject private var importRequests = ConfigImportRequests.shared

    var body: some View {
        HStack(spacing: 0) {
            LauncherSidebar(
                onNewConfiguration: addNewConfiguration,
                onNewGroup: { showGroupNamePrompt(for: nil) },
                onImport: pickImportFile,
                onExport: { passwordError = nil; passwordPrompt = .export },
                canExport: !configManager.configurations.isEmpty
            )

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
        .sheet(item: $passwordPrompt) { prompt in
            passwordSheet(for: prompt)
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
        .alert(
            "删除分组",
            isPresented: Binding(
                get: { groupToDelete != nil },
                set: { if !$0 { groupToDelete = nil } }
            ),
            presenting: groupToDelete
        ) { group in
            Button("删除", role: .destructive) {
                configManager.deleteGroup(group.id)
            }
            Button("取消", role: .cancel) {}
        } message: { group in
            Text("确定要删除分组 \"\(group.name)\" 吗？其中的配置会移到「未分组」，不会被删除。")
        }
        .alert(
            groupNamePrompt?.groupId == nil ? "新建分组" : "重命名分组",
            isPresented: Binding(
                get: { groupNamePrompt != nil },
                set: { if !$0 { groupNamePrompt = nil } }
            ),
            presenting: groupNamePrompt
        ) { prompt in
            TextField("分组名称", text: $groupNameText)
            Button("取消", role: .cancel) {}
            Button(prompt.groupId == nil ? "创建" : "确定") {
                commitGroupName(prompt)
            }
        }
        .alert(
            "提示",
            isPresented: Binding(
                get: { noticeMessage != nil },
                set: { if !$0 { noticeMessage = nil } }
            )
        ) {
            Button("好") {}
        } message: {
            Text(noticeMessage ?? "")
        }
        .onChange(of: importRequests.pendingURL, initial: true) { _, url in
            guard let url else { return }
            importRequests.pendingURL = nil
            // 正在编辑或输入密码时先关掉，避免两个弹出窗口冲突
            editTarget = nil
            passwordPrompt = nil
            DispatchQueue.main.async { loadImportFile(url) }
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

            if configManager.configurations.isEmpty && configManager.groups.isEmpty {
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
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(configManager.groups) { group in
                            groupSection(group)
                        }
                        ungroupedSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func groupSection(_ group: ConfigGroup) -> some View {
        let items = configManager.configurations(in: group.id)
        let isExpanded = Binding(
            get: { !collapsedGroups.contains(group.id) },
            set: { expanded in
                if expanded { collapsedGroups.remove(group.id) } else { collapsedGroups.insert(group.id) }
            }
        )

        ConfigGroupHeader(
            title: group.name,
            count: items.count,
            isExpanded: isExpanded,
            onRename: { showGroupNamePrompt(for: group) },
            onDelete: { groupToDelete = group }
        )

        if isExpanded.wrappedValue {
            if items.isEmpty {
                Text("空分组，可在配置的右键菜单中移入")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            } else {
                ForEach(items, id: \.id) { row(for: $0) }
            }
        }
    }

    @ViewBuilder
    private var ungroupedSection: some View {
        let items = configManager.configurations(in: nil)
        // 没有任何分组时不显示「未分组」标题，列表保持简洁
        if !configManager.groups.isEmpty && !items.isEmpty {
            ConfigGroupHeader(title: "未分组", count: items.count)
                .padding(.top, 4)
        }
        ForEach(items, id: \.id) { row(for: $0) }
    }

    private func row(for config: OSSConfiguration) -> some View {
        ConfigurationRow(
            config: config,
            onEdit: { editTarget = EditTarget(config: config, isCreatingNew: false) },
            onOpen: { openWindow(value: config) },
            onDuplicate: { configManager.duplicateConfiguration(config) },
            onDelete: { configToDelete = config },
            groups: configManager.groups,
            currentGroupId: configManager.groupId(of: config.id),
            onMove: { configManager.moveConfiguration(config.id, to: $0) }
        )
    }

    // MARK: - 配置

    private func addNewConfiguration() {
        editTarget = EditTarget(
            config: OSSConfiguration(name: "", accessKeyId: "", accessKeySecret: "", region: "cn-hangzhou"),
            isCreatingNew: true
        )
    }

    // MARK: - 分组

    private func showGroupNamePrompt(for group: ConfigGroup?) {
        groupNameText = group?.name ?? ""
        groupNamePrompt = GroupNamePrompt(groupId: group?.id)
    }

    private func commitGroupName(_ prompt: GroupNamePrompt) {
        let name = groupNameText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if let groupId = prompt.groupId {
            configManager.renameGroup(groupId, to: name)
        } else {
            configManager.createGroup(named: name)
        }
    }

    // MARK: - 导入导出

    private func passwordSheet(for prompt: PasswordPrompt) -> some View {
        switch prompt {
        case .export:
            return PasswordPromptSheet(
                title: "导出配置",
                message: "导出的文件包含 AccessKey Secret，会用这个密码加密。导入时需要输入同一个密码，请妥善保管。",
                requiresConfirmation: true,
                confirmTitle: "导出…",
                errorMessage: passwordError,
                onSubmit: { password in
                    passwordPrompt = nil
                    // 等弹出窗口关闭后再显示保存面板
                    DispatchQueue.main.async { exportConfigurations(password: password) }
                },
                onCancel: { passwordPrompt = nil }
            )
        case .import(let data):
            return PasswordPromptSheet(
                title: "导入配置",
                message: "请输入导出这个文件时设置的密码。已存在的配置会被跳过。",
                requiresConfirmation: false,
                confirmTitle: "导入",
                errorMessage: passwordError,
                onSubmit: { password in importConfigurations(from: data, password: password) },
                onCancel: { passwordPrompt = nil }
            )
        }
    }

    private func exportConfigurations(password: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [ConfigurationArchive.contentType]
        panel.canCreateDirectories = true
        let date = Date().formatted(.iso8601.year().month().day())
        panel.nameFieldStringValue = "OSSBrowser 配置 \(date).\(ConfigurationArchive.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try ConfigurationArchive.encrypt(configManager.exportPayload(), password: password)
            try data.write(to: url, options: .atomic)
            noticeMessage = "已导出 \(configManager.configurations.count) 个配置、\(configManager.groups.count) 个分组。"
        } catch {
            noticeMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func pickImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [ConfigurationArchive.contentType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadImportFile(url)
    }

    /// 读取待导入文件并弹出密码输入（手动选择与双击打开共用）
    private func loadImportFile(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            passwordError = nil
            passwordPrompt = .import(data)
        } catch {
            noticeMessage = "读取文件失败：\(error.localizedDescription)"
        }
    }

    private func importConfigurations(from data: Data, password: String) {
        let payload: ConfigurationArchive.Payload
        do {
            payload = try ConfigurationArchive.decrypt(data, password: password)
        } catch ConfigurationArchive.ArchiveError.wrongPassword {
            // 密码错误时保留弹出窗口，让用户重新输入
            passwordError = ConfigurationArchive.ArchiveError.wrongPassword.localizedDescription
            return
        } catch {
            passwordPrompt = nil
            noticeMessage = "导入失败：\(error.localizedDescription)"
            return
        }

        passwordPrompt = nil
        let result = configManager.importPayload(payload)
        noticeMessage = result.skipped > 0
            ? "已导入 \(result.imported) 个配置，跳过 \(result.skipped) 个已存在的配置。"
            : "已导入 \(result.imported) 个配置。"
    }
}

#Preview {
    ConfigurationListView()
}
