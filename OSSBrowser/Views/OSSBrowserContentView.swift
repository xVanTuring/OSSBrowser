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
                OSSFileBrowserView(bucket: bucket, config: config)
                    .navigationSplitViewColumnWidth(min:500,ideal: 600)
            } else {
                ContentUnavailableView(
                    "选择一个 Bucket",
                    systemImage: "archivebox",
                    description: Text("从左侧选择一个 Bucket 来查看文件")
                )
            }
        } detail: {
            // 右侧详情区
            if let bucket = selectedBucket {
                BucketDetailView(bucket: bucket)
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
