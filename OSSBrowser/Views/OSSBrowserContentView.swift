//
//  OSSBrowserContentView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI

/// 点击收藏后待导航的目标；id 每次生成都不同，用于强制文件浏览视图重建并跳转到指定路径
private struct FavoriteNavigationTarget: Identifiable {
    let id = UUID()
    let bucket: BucketItem
    let path: String
}

/// 收藏项失效时的确认删除弹窗信息
private struct FavoriteIssue: Identifiable {
    let id: UUID
    let favorite: FavoritePath
    let reason: String

    init(favorite: FavoritePath, reason: String) {
        self.id = favorite.id
        self.favorite = favorite
        self.reason = reason
    }
}

struct OSSBrowserContentView: View {
    let config: OSSConfiguration
    @ObservedObject var ossService: OSSService
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @State private var buckets: [BucketItem] = []
    @State private var selectedBucket: BucketItem?
    @State private var isLoading = true

    // 文件状态信息
    @State private var currentFileCount = 0
    @State private var currentSelectedCount = 0
    @State private var currentIsLoading = false

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var inspectShow: Bool = true

    @State private var favoriteNavigationTarget: FavoriteNavigationTarget?
    @State private var favoriteIssue: FavoriteIssue?

    private var favorites: [FavoritePath] {
        favoritesManager.favorites(for: config.id)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 左侧边栏 - 上方 Bucket 切换，下方按 Bucket 分组的路径收藏
            BucketSidebarView(
                buckets: buckets,
                selectedBucket: $selectedBucket,
                isLoading: isLoading,
                favorites: favorites,
                onSelectFavorite: handleSelectFavorite,
                onDeleteFavorite: { favoritesManager.removeFavorite($0) }
            )
        } detail: {
            // 中间内容区 - 文件列表
            if let bucket = selectedBucket {
                NavigationStack {
                    OSSFileBrowserContent(
                        bucket: bucket,
                        config: config,
                        initialPath: favoriteNavigationTarget?.bucket.id == bucket.id
                            ? favoriteNavigationTarget?.path : nil,
                        onInvalidFavoritePath: { path in
                            handleInvalidFavoritePath(bucketName: bucket.name, path: path)
                        },
                        inspectorPresented: $inspectShow,
                        onFileCountUpdate: { itemCount, selectedCount, isLoading in
                            // 传递文件状态信息到详情面板
                            currentFileCount = itemCount
                            currentSelectedCount = selectedCount
                            currentIsLoading = isLoading
                        }
                    )
                    .navigationTitle(bucket.name)
                }
                // 普通切换 bucket 用 bucket.id；来自收藏的导航用独立的 target id，
                // 确保即使目标 bucket 与当前一致也会重新加载到指定路径
                .id(favoriteNavigationTarget?.bucket.id == bucket.id
                    ? favoriteNavigationTarget!.id : bucket.id)
            } else {
                ContentUnavailableView(
                    "选择一个 Bucket",
                    systemImage: "archivebox",
                    description: Text("从左侧选择一个 Bucket 来查看文件")
                )
            }
        }.inspector(isPresented: $inspectShow) {
            if let bucket = selectedBucket {
                BucketDetailView(
                    bucket: bucket,
                    fileCount: currentFileCount,
                    selectedCount: currentSelectedCount,
                    isLoading: currentIsLoading
                )
            } else {
                Text("选择一个 Bucket 查看详情")
                    .foregroundColor(.secondary)
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .onAppear {
            loadBuckets()
        }.toolbarBackground(.hidden, for: .windowToolbar)
        .alert(item: $favoriteIssue) { issue in
            Alert(
                title: Text("收藏已失效"),
                message: Text("「\(issue.favorite.displayName)」\(issue.reason)，是否删除该收藏？"),
                primaryButton: .destructive(Text("删除收藏")) {
                    favoritesManager.removeFavorite(issue.favorite)
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    // MARK: - Favorites

    private func handleSelectFavorite(_ favorite: FavoritePath) {
        guard !isLoading else { return }
        guard let bucket = buckets.first(where: { $0.name == favorite.bucketName }) else {
            favoriteIssue = FavoriteIssue(favorite: favorite, reason: "所在 Bucket 不存在")
            return
        }
        selectedBucket = bucket
        favoriteNavigationTarget = FavoriteNavigationTarget(bucket: bucket, path: favorite.path)
    }

    private func handleInvalidFavoritePath(bucketName: String, path: String) {
        guard let favorite = favorites.first(where: { $0.bucketName == bucketName && $0.path == path }) else {
            return
        }
        favoriteIssue = FavoriteIssue(favorite: favorite, reason: "路径不存在")
    }

    private func loadBuckets() {
        Task {
            do {
                try await ossService.connect(with: config)
                buckets = try await ossService.listBuckets()

                await MainActor.run {
                    isLoading = false
                    if !buckets.isEmpty {
                        selectedBucket = buckets.first
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // TODO: 显示错误
                }
            }
        }
    }
}

#Preview {
    OSSBrowserContentView(
        config: OSSConfiguration(
            name: "Test",
            accessKeyId: "",
            accessKeySecret: "",
            region: "cn-shenzhen"
        ),
        ossService: OSSService()
    ).frame(width: 1200, height: 500)
}
