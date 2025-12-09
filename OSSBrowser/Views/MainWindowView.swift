//
//  MainWindowView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI

struct MainWindowView: View {
    let config: OSSConfiguration
    @StateObject private var ossService = OSSService()
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
        } content: {
            // 中间内容区 - 文件列表
            if let bucket = selectedBucket {
                FileListView(bucket: bucket, config: config)
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
            } else {
                Text("选择一个 Bucket 查看详情")
                    .foregroundColor(.secondary)
            }
        }
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

struct BucketListView: View {
    let buckets: [BucketItem]
    @Binding var selectedBucket: BucketItem?
    let isLoading: Bool

    var body: some View {
        List(buckets, id: \.id, selection: $selectedBucket) { bucket in
            VStack(alignment: .leading) {
                Text(bucket.name)
                    .font(.headline)
                Text(bucket.region)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .tag(bucket)
        }
        .navigationTitle("Buckets")
        .overlay {
            if isLoading {
                ProgressView()
            } else if buckets.isEmpty {
                ContentUnavailableView(
                    "没有 Bucket",
                    systemImage: "archivebox",
                    description: Text("该账号下没有 Bucket")
                )
            }
        }
    }
}

struct BucketDetailView: View {
    let bucket: BucketItem

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(bucket.name)
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Region", systemImage: "location")
                    Spacer()
                    Text(bucket.region)
                }
                HStack {
                    Label("Storage", systemImage: "externaldrive")
                    Spacer()
                    Text(bucket.storageClass)
                }
                HStack {
                    Label("Created", systemImage: "calendar")
                    Spacer()
                    Text(bucket.creationDate, style: .date)
                }
            }
            .font(.body)

            Spacer()
        }
        .padding()
        .navigationTitle("详情")
    }
}

#Preview {
    MainWindowView(config: OSSConfiguration(
        name: "Test",
        accessKeyId: "",
        accessKeySecret: "",
        region: "cn-hangzhou"
    ))
}