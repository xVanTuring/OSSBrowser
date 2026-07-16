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

    var body: some View {
        List {
            ForEach(groups, id: \.bucketName) { group in
                Section(group.bucketName) {
                    ForEach(group.items) { favorite in
                        Button {
                            onSelect(favorite)
                        } label: {
                            Label(
                                favorite.displayName,
                                systemImage: favorite.path.isEmpty ? "archivebox" : "folder"
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(favorite)
                            } label: {
                                Label("删除收藏", systemImage: "trash")
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                onDelete(favorite)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .navigationTitle("收藏")
        .disabled(isLoading)
        .overlay {
            if favorites.isEmpty {
                ContentUnavailableView(
                    "暂无收藏",
                    systemImage: "star",
                    description: Text("浏览文件时点击路径栏右侧的星标即可收藏")
                )
            }
        }
    }
}

#Preview {
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
}
