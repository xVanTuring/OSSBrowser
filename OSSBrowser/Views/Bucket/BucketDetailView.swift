//
//  BucketDetailView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI

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
    BucketDetailView(
        bucket: BucketItem(
            name: "test-bucket",
            region: "cn-hangzhou",
            creationDate: Date(),
            storageClass: "Standard"
        )
    )
}