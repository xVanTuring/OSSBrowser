//
//  ConfigurationManager.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ConfigurationManager: ObservableObject {
    @Published var configurations: [OSSConfiguration] = []
    /// 分组（数组顺序即显示顺序）
    @Published private(set) var groups: [ConfigGroup] = []
    /// 配置 ID → 分组 ID；不在其中的配置为「未分组」
    @Published private(set) var groupAssignments: [UUID: UUID] = [:]

    private let keychainManager = KeychainManager()

    /// 分组不含敏感信息，存 UserDefaults
    private static let groupsDefaultsKey = "configGroups.v1"

    private struct GroupState: Codable {
        var groups: [ConfigGroup]
        var assignments: [UUID: UUID]
    }

    init() {
        print("ConfigurationManager: Initializing...")

        // 运行 Keychain 测试（仅在 Debug 模式）
//        #if DEBUG
//        KeychainTest.runTest()
//        #endif

        loadConfigurations()
        loadGroups()
        print("ConfigurationManager: Initialized with \(configurations.count) configurations")
    }

    func addConfiguration(_ config: OSSConfiguration) {
        print("ConfigurationManager: Adding configuration \(config.name)")
        configurations.append(config)
        saveConfiguration(config)
        print("ConfigurationManager: Total configurations after adding: \(configurations.count)")
    }

    func updateConfiguration(_ config: OSSConfiguration) {
        print("ConfigurationManager: Updating configuration \(config.name) with id \(config.id)")
        if let index = configurations.firstIndex(where: { $0.id == config.id }) {
            print("ConfigurationManager: Found configuration at index \(index)")
            configurations[index] = config
            saveConfiguration(config)
            print("ConfigurationManager: Configuration updated and saved")
        } else {
            print("ConfigurationManager: Configuration not found!")
        }
    }

    func deleteConfiguration(_ config: OSSConfiguration) {
        configurations.removeAll { $0.id == config.id }
        keychainManager.deleteConfiguration(config.id)
        if groupAssignments.removeValue(forKey: config.id) != nil {
            saveGroups()
        }
    }

    /// 复制一份配置（生成新 ID，名称追加「副本」），返回新配置
    @discardableResult
    func duplicateConfiguration(_ config: OSSConfiguration) -> OSSConfiguration {
        let copy = OSSConfiguration(
            name: uniqueCopyName(for: config.name),
            accessKeyId: config.accessKeyId,
            accessKeySecret: config.accessKeySecret,
            region: config.region,
            endpoint: config.endpoint
        )
        addConfiguration(copy)
        // 副本放在原配置所在的分组
        if let groupId = groupAssignments[config.id] {
            moveConfiguration(copy.id, to: groupId)
        }
        return copy
    }

    // MARK: - 分组

    /// 某个分组下的配置；groupId 为 nil 时返回未分组的配置
    func configurations(in groupId: UUID?) -> [OSSConfiguration] {
        configurations.filter { groupAssignments[$0.id] == groupId }
    }

    func groupId(of configId: UUID) -> UUID? {
        groupAssignments[configId]
    }

    @discardableResult
    func createGroup(named name: String) -> ConfigGroup {
        let group = ConfigGroup(name: name)
        groups.append(group)
        saveGroups()
        return group
    }

    func renameGroup(_ groupId: UUID, to name: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        groups[index].name = name
        saveGroups()
    }

    /// 删除分组；其中的配置变为未分组，不会被删除
    func deleteGroup(_ groupId: UUID) {
        groups.removeAll { $0.id == groupId }
        groupAssignments = groupAssignments.filter { $0.value != groupId }
        saveGroups()
    }

    /// 移动配置到分组；groupId 为 nil 表示移出分组
    func moveConfiguration(_ configId: UUID, to groupId: UUID?) {
        groupAssignments[configId] = groupId
        saveGroups()
    }

    private func saveGroups() {
        let state = GroupState(groups: groups, assignments: groupAssignments)
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: Self.groupsDefaultsKey)
        } catch {
            print("Failed to save groups: \(error)")
        }
    }

    private func loadGroups() {
        guard let data = UserDefaults.standard.data(forKey: Self.groupsDefaultsKey),
              let state = try? JSONDecoder().decode(GroupState.self, from: data)
        else { return }
        groups = state.groups
        // 丢弃指向已不存在的配置或分组的记录
        let configIds = Set(configurations.map(\.id))
        let groupIds = Set(groups.map(\.id))
        groupAssignments = state.assignments.filter { configIds.contains($0.key) && groupIds.contains($0.value) }
    }

    // MARK: - 导入导出

    /// 导出全部配置与分组
    func exportPayload() -> ConfigurationArchive.Payload {
        ConfigurationArchive.Payload(
            groups: groups,
            items: configurations.map { .init(configuration: $0, groupId: groupAssignments[$0.id]) }
        )
    }

    struct ImportResult {
        var imported = 0
        var skipped = 0
    }

    /// 合并导入：已存在（相同 ID）的配置跳过；分组先按 ID、再按名称匹配，都没有则新建
    func importPayload(_ payload: ConfigurationArchive.Payload) -> ImportResult {
        // 文件中的分组 ID → 本地分组 ID
        var groupMap: [UUID: UUID] = [:]
        for group in payload.groups {
            if groups.contains(where: { $0.id == group.id }) {
                groupMap[group.id] = group.id
            } else if let sameName = groups.first(where: { $0.name == group.name }) {
                groupMap[group.id] = sameName.id
            } else {
                groups.append(group)
                groupMap[group.id] = group.id
            }
        }

        var result = ImportResult()
        let existingIds = Set(configurations.map(\.id))
        for item in payload.items {
            guard !existingIds.contains(item.configuration.id) else {
                result.skipped += 1
                continue
            }
            addConfiguration(item.configuration)
            if let fileGroupId = item.groupId, let localGroupId = groupMap[fileGroupId] {
                groupAssignments[item.configuration.id] = localGroupId
            }
            result.imported += 1
        }
        saveGroups()
        return result
    }

    /// 生成不与现有名称冲突的「副本」名称
    private func uniqueCopyName(for name: String) -> String {
        let base = "\(name) 副本"
        let existing = Set(configurations.map { $0.name })
        if !existing.contains(base) { return base }
        var index = 2
        while existing.contains("\(base) \(index)") { index += 1 }
        return "\(base) \(index)"
    }

    private func saveConfiguration(_ config: OSSConfiguration) {
        do {
            try keychainManager.saveConfiguration(config)
        } catch {
            print("Failed to save configuration: \(error)")
        }
    }

    private func loadConfigurations() {
        do {
            configurations = try keychainManager.loadConfigurations()
        } catch {
            print("Failed to load configurations: \(error)")
        }
    }
}
