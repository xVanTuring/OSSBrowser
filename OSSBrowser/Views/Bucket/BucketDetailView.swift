//
//  BucketDetailView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI
import AppKit

struct BucketDetailView: View {
    let bucket: BucketItem
    let fileCount: Int
    let selectedCount: Int
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Bucket 信息
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text(bucket.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textSelection(.enabled)

                    Button {
                        copyToPasteboard(bucket.name)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("复制桶名")
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("区域", systemImage: "location")
                        Spacer()
                        Text(bucket.region)
                            .textSelection(.enabled)
                    }
                    HStack {
                        Label("存储类型", systemImage: "externaldrive")
                        Spacer()
                        Text(bucket.storageClass)
                            .textSelection(.enabled)
                    }
                    HStack {
                        Label("创建时间", systemImage: "calendar")
                        Spacer()
                        Text(bucket.creationDate, style: .date)
                            .textSelection(.enabled)
                    }
                }
                .font(.body)
            }

            Divider()

            // 文件状态信息
            VStack(alignment: .leading, spacing: 10) {
                Text("文件状态")
                    .font(.headline)

                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("加载中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(fileCount) 个项目")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if selectedCount > 0 {
                            Text("· \(selectedCount) 个已选择")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("详情")
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

#Preview {
    BucketDetailView(
        bucket: BucketItem(
            name: "test-bucket",
            region: "cn-hangzhou",
            creationDate: Date(),
            storageClass: "Standard"
        ),
        fileCount: 42,
        selectedCount: 3,
        isLoading: false
    )
}