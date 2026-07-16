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

    private let minTop: CGFloat = 120
    private let minBottom: CGFloat = 120
    @State private var topHeight: CGFloat = 260
    @State private var dragStartHeight: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let total = geo.size.height
            let maxTop = max(minTop, total - minBottom)
            let clampedTop = min(max(topHeight, minTop), maxTop)

            VStack(spacing: 0) {
                BucketListView(
                    buckets: buckets,
                    selectedBucket: $selectedBucket,
                    isLoading: isLoading
                )
                .frame(height: clampedTop)

                SidebarSplitHandle()
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if dragStartHeight == nil { dragStartHeight = clampedTop }
                                let proposed = (dragStartHeight ?? clampedTop) + value.translation.height
                                topHeight = min(max(proposed, minTop), maxTop)
                            }
                            .onEnded { _ in dragStartHeight = nil }
                    )

                FavoritesListView(
                    favorites: favorites,
                    isLoading: isLoading,
                    onSelect: onSelectFavorite,
                    onDelete: onDeleteFavorite
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// 上下两栏之间的可拖拽分隔条：系统分隔色（深浅色自适应），hover 时提亮并显示上下调整光标
private struct SidebarSplitHandle: View {
    @State private var isHovered = false

    var body: some View {
        ZStack {
            Color.clear
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
                .opacity(isHovered ? 1 : 0.65)
        }
        .frame(height: 11)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
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
