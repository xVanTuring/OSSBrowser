//
//  FileListView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI

struct FileListView: View {
    let bucket: BucketItem
    let config: OSSConfiguration

    var body: some View {
        VStack {
            Text("文件列表")
                .font(.headline)
            Text("Bucket: \(bucket.name)")
                .font(.caption)
                .foregroundColor(.secondary)

            // TODO: 实现文件列表
            ContentUnavailableView(
                "文件列表功能待实现",
                systemImage: "doc.text",
                description: Text("此功能将在下一步实现")
            )
        }
        .padding()
    }
}

#Preview {
    FileListView(
        bucket: BucketItem(
            name: "test-bucket",
            region: "cn-hangzhou",
            creationDate: Date(),
            storageClass: "Standard"
        ),
        config: OSSConfiguration(
            name: "Test",
            accessKeyId: "",
            accessKeySecret: "",
            region: "cn-hangzhou"
        )
    )
}