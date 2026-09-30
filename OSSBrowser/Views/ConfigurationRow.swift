//
//  ConfigurationRow.swift
//  OSSBrowser
//
//  启动窗口中的一行配置：名称 + 区域，右侧「编辑」「打开」。双击整行也会打开。
//

import SwiftUI

struct ConfigurationRow: View {
    let config: OSSConfiguration
    let onEdit: () -> Void
    let onOpen: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    /// 所有分组与当前所属分组，用于「移动到分组」菜单
    let groups: [ConfigGroup]
    let currentGroupId: UUID?
    let onMove: (UUID?) -> Void

    @State private var isHovering = false

    /// 副标题：区域；有自定义 Endpoint 时一并显示
    private var subtitle: String {
        guard let endpoint = config.endpoint, !endpoint.isEmpty else { return config.region }
        return "\(config.region) · \(endpoint)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            Button("编辑", action: onEdit)
                .buttonStyle(.bordered)
            Button("打开", action: onOpen)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(isHovering ? 0.08 : 0.05))
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2, perform: onOpen)
        .contextMenu {
            Button(action: onOpen) {
                Label("打开", systemImage: "macwindow")
            }
            Button(action: onEdit) {
                Label("编辑", systemImage: "pencil")
            }
            Button(action: onDuplicate) {
                Label("复制配置", systemImage: "plus.square.on.square")
            }
            if !groups.isEmpty {
                Menu {
                    ForEach(groups) { group in
                        Button(group.name) { onMove(group.id) }
                            .disabled(group.id == currentGroupId)
                    }
                    Divider()
                    Button("未分组") { onMove(nil) }
                        .disabled(currentGroupId == nil)
                } label: {
                    Label("移动到分组", systemImage: "folder")
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}
