//
//  FavoritesListView.swift
//  OSSBrowser
//

import SwiftUI

struct FavoritesListView: View {
    let favorites: [FavoritePath]
    let isLoading: Bool
    let onSelect: (FavoritePath) -> Void
    let onDelete: (FavoritePath) -> Void

    private var groups: [(bucketName: String, items: [FavoritePath])] {
        let grouped = Dictionary(grouping: favorites, by: \.bucketName)
        return grouped.keys.sorted().map { key in
            (key, grouped[key]!.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending })
        }
    }

    /// 仅当收藏跨多个 Bucket 时才显示 Bucket 分组标题，避免与根目录项重名
    private var showBucketHeaders: Bool { groups.count > 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if favorites.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(groups, id: \.bucketName) { group in
                            if showBucketHeaders {
                                Text(group.bucketName)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                    .padding(.bottom, 1)
                            }
                            ForEach(group.items) { favorite in
                                FavoriteRow(
                                    favorite: favorite,
                                    onSelect: { onSelect(favorite) },
                                    onDelete: { onDelete(favorite) }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .disabled(isLoading)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
            Text("收藏")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "star")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("暂无收藏")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("浏览文件时点击路径栏的星标即可收藏当前目录")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }
}

/// 单个收藏行：hover 高亮、全路径 tooltip、右键删除
private struct FavoriteRow: View {
    let favorite: FavoritePath
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var isRoot: Bool { favorite.path.isEmpty }

    private var title: String { isRoot ? "根目录" : favorite.displayName }

    private var fullPath: String {
        isRoot ? favorite.bucketName : "\(favorite.bucketName)/\(favorite.path)"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: isRoot ? "house.fill" : "folder.fill")
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(fullPath)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("删除收藏", systemImage: "trash")
            }
        }
        .padding(.horizontal, 8)
    }
}

#Preview("多 Bucket") {
    FavoritesListView(
        favorites: [
            FavoritePath(configId: UUID(), bucketName: "test-bucket-1", path: "folder1/folder2"),
            FavoritePath(configId: UUID(), bucketName: "test-bucket-1", path: ""),
            FavoritePath(configId: UUID(), bucketName: "test-bucket-2", path: "docs")
        ],
        isLoading: false,
        onSelect: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 260, height: 300)
}

#Preview("单 Bucket") {
    FavoritesListView(
        favorites: [
            FavoritePath(configId: UUID(), bucketName: "snkxd-ai", path: "oem-cover"),
            FavoritePath(configId: UUID(), bucketName: "snkxd-ai", path: ""),
            FavoritePath(configId: UUID(), bucketName: "snkxd-ai", path: "test")
        ],
        isLoading: false,
        onSelect: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 260, height: 300)
}

#Preview("空") {
    FavoritesListView(
        favorites: [],
        isLoading: false,
        onSelect: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 260, height: 300)
}
