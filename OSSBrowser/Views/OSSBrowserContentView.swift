//
//  OSSBrowserContentView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI

struct OSSBrowserContentView: View {
    let config: OSSConfiguration
    @ObservedObject var ossService: OSSService
    @State private var buckets: [BucketItem] = []
    @State private var selectedBucket: BucketItem?
    @State private var isLoading = true

    // 文件状态信息
    @State private var currentFileCount = 0
    @State private var currentSelectedCount = 0
    @State private var currentIsLoading = false

    // 当前路径
    @State private var currentPath = ""

    // 文件服务引用，用于路径导航
    @State private var fileServiceRef: OSSFileService?

    var body: some View {
        NavigationSplitView {
            // 左侧边栏 - Bucket 列表
            BucketListView(
                buckets: buckets,
                selectedBucket: $selectedBucket,
                isLoading: isLoading
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } content: {
            // 中间内容区 - 文件列表
            if let bucket = selectedBucket {
                NavigationStack {
                    VStack(spacing: 0) {
                        OSSFileBrowserContent(
                            bucket: bucket,
                            config: config,
                            onFileCountUpdate: { itemCount, selectedCount, isLoading in
                                // 传递文件状态信息到详情面板
                                currentFileCount = itemCount
                                currentSelectedCount = selectedCount
                                currentIsLoading = isLoading
                            },
                            onPathChange: { newPath in
                                currentPath = newPath
                            },
                            onFileServiceReady: { fileService in
                                self.fileServiceRef = fileService
                            }
                        )

                        // 底部路径导航栏
                        PathNavigationView(
                            bucketName: bucket.name,
                            currentPath: currentPath,
                            onPathClick: { path in
                                Task {
                                    await navigateToPath(path)
                                }
                            }
                        )
                    }
                    .navigationTitle(bucket.name)
                    .toolbar {
                        // 左侧导航按钮
                        ToolbarItemGroup(placement: .navigation) {
                            // 由 OSSFileBrowserContent 内部定义
                        }

                        // 中间路径导航（暂时跳过）
                        // TODO: 添加路径导航

                        // 右侧操作按钮
                        ToolbarItemGroup(placement: .primaryAction) {
                            // 由 OSSFileBrowserContent 内部定义
                        }
                    }
                }
                .id(bucket.id) // 添加 id 以确保在切换 bucket 时重新创建视图
                .navigationSplitViewColumnWidth(min:500,ideal: 600)
            } else {
                ContentUnavailableView(
                    "选择一个 Bucket",
                    systemImage: "archivebox",
                    description: Text("从左侧选择一个 Bucket 来查看文件")
                )
            }
        } detail: {
            // 右侧详情区 - 现在包含文件状态信息
            if let bucket = selectedBucket {
                BucketDetailView(
                    bucket: bucket,
                    fileCount: currentFileCount,
                    selectedCount: currentSelectedCount,
                    isLoading: currentIsLoading
                )
                .frame(maxWidth: 300)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            } else {
                Text("选择一个 Bucket 查看详情")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 300)
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .onAppear {
            loadBuckets()
        }
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

    private func navigateToPath(_ path: String) async {
        guard let fileService = fileServiceRef else { return }
        do {
            try await fileService.listFiles(at: path)
        } catch {
            print("Failed to navigate to path \(path): \(error)")
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
    ).frame(width: 1200,height: 500)
}
