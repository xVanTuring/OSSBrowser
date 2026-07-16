//
//  BucketSidebarView.swift
//  OSSBrowser
//

import SwiftUI

/// 左侧边栏：上方 Bucket 切换，下方按 Bucket 分组的路径收藏
struct BucketSidebarView: View {
    let buckets: [BucketItem]
    @Binding var selectedBucket: BucketItem?
    let isLoading: Bool
    let favorites: [FavoritePath]
    let onSelectFavorite: (FavoritePath) -> Void
    let onDeleteFavorite: (FavoritePath) -> Void

    var body: some View {
        VSplitView {
            BucketListView(
                buckets: buckets,
                selectedBucket: $selectedBucket,
                isLoading: isLoading
            )
            .frame(minHeight: 120)

            FavoritesListView(
                favorites: favorites,
                isLoading: isLoading,
                onSelect: onSelectFavorite,
                onDelete: onDeleteFavorite
            )
            .frame(minHeight: 120)
        }
    }
}

#Preview {
    BucketSidebarView(
        buckets: [
            BucketItem(name: "test-bucket-1", region: "cn-hangzhou", creationDate: Date(), storageClass: "Standard")
        ],
        selectedBucket: .constant(nil),
        isLoading: false,
        favorites: [
            FavoritePath(configId: UUID(), bucketName: "test-bucket-1", path: "folder1")
        ],
        onSelectFavorite: { _ in },
        onDeleteFavorite: { _ in }
    )
    .frame(width: 260, height: 500)
}
