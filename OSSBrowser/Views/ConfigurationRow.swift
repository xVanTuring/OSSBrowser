//
//  ConfigurationRow.swift
//  OSSBrowser
//
//  配置列表的一行。图标颜色随选中状态切换，避免强调色图标压在强调色选中背景上看不见。
//

import SwiftUI

struct ConfigurationRow: View {
    let config: OSSConfiguration
    /// 选中时背景为强调色，图标改为白色
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .font(.title3)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(config.region)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .help("双击打开")
    }
}
