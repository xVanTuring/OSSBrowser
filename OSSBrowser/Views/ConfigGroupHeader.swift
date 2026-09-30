//
//  ConfigGroupHeader.swift
//  OSSBrowser
//
//  启动窗口配置列表中的分组标题：折叠箭头、名称、数量，右侧「…」菜单（重命名、删除）。
//  「未分组」不可折叠，也没有菜单。
//

import SwiftUI

struct ConfigGroupHeader: View {
    let title: String
    let count: Int
    /// nil 表示不可折叠（未分组）
    var isExpanded: Binding<Bool>? = nil
    var onRename: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let isExpanded {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                    .frame(width: 14)
            } else {
                Image(systemName: "tray")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.tertiary)

            Spacer()

            if onRename != nil || onDelete != nil {
                Menu {
                    if let onRename {
                        Button("重命名分组…", action: onRename)
                    }
                    if let onDelete {
                        Divider()
                        Button("删除分组", role: .destructive, action: onDelete)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("分组操作")
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let isExpanded else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.wrappedValue.toggle()
            }
        }
    }
}
