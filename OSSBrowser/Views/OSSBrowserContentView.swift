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

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var inspectShow: Bool = true

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 左侧边栏 - Bucket 列表
            BucketListView(
                buckets: buckets,
                selectedBucket: $selectedBucket,
                isLoading: isLoading
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            // 中间内容区 - 文件列表
            if let bucket = selectedBucket {
                NavigationStack {
                    OSSFileBrowserContent(
                        bucket: bucket,
                        config: config,
                        onFileCountUpdate: { itemCount, selectedCount, isLoading in
                            // 传递文件状态信息到详情面板
                            currentFileCount = itemCount
                            currentSelectedCount = selectedCount
                            currentIsLoading = isLoading
                        }
                    )
                    .navigationTitle(bucket.name)
                }
                .id(bucket.id)  // 添加 id 以确保在切换 bucket 时重新创建视图
                .navigationSplitViewColumnWidth(min: 500, ideal: 600)
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
        }.toolbarBackground(.hidden, for: .windowToolbar)
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
