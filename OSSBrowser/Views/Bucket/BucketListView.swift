//
//  BucketListView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI

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

#Preview {
    BucketListView(
        buckets: [
            BucketItem(
                name: "test-bucket-1",
                region: "cn-hangzhou",
                creationDate: Date(),
                storageClass: "Standard"
            ),
            BucketItem(
                name: "test-bucket-2",
                region: "cn-beijing",
                creationDate: Date(),
                storageClass: "IA"
            )
        ],
        selectedBucket: .constant(nil),
        isLoading: false
    )
}