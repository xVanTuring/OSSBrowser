//
//  ConnectionTestView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import SwiftUI

struct ConnectionTestView: View {
    @StateObject private var ossService = OSSService()
    @State private var accessKeyId = ""
    @State private var accessKeySecret = ""
    @State private var region = "cn-shenzhen"
    @State private var isLoading = false
    @State private var isConnected = false
    @State private var buckets: [BucketItem] = []
    @State private var errorMessage = ""
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 20) {
            Text("OSS 连接测试")
                .font(.largeTitle)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading) {
                    Text("Access Key ID")
                        .font(.headline)
                    TextField("请输入 Access Key ID", text: $accessKeyId)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Access Key Secret")
                        .font(.headline)
                    SecureField("请输入 Access Key Secret", text: $accessKeySecret)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Region")
                        .font(.headline)
                    TextField("例如: cn-hangzhou", text: $region)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .frame(maxWidth: 400)

            Button(action: testConnection) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "连接中..." : "测试连接")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(accessKeyId.isEmpty || accessKeySecret.isEmpty || region.isEmpty || isLoading)

            if isConnected {
                Text("✅ 连接成功！")
                    .foregroundColor(.green)
                    .font(.headline)
                    .padding(.top, 10)

                Text("找到 \(buckets.count) 个 Bucket:")
                    .font(.subheadline)
                    .padding(.top, 5)

                List(buckets, id: \.id) { bucket in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(bucket.name)
                            .font(.headline)
                        HStack {
                            Text("Region: \(bucket.region)")
                            Spacer()
                            Text("Storage: \(bucket.storageClass)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                }
                .frame(maxHeight: 300)
                .border(Color.gray.opacity(0.3), width: 1)
            }

            Spacer()
        }
        .padding(40)
        .frame(minWidth: 600, minHeight: 500)
        .alert("错误", isPresented: $showingError) {
            Button("确定") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func testConnection() {
        isLoading = true
        errorMessage = ""
        isConnected = false
        buckets = []

        Task {
            do {
                // 使用默认 endpoint
                let defaultEndpoint = "https://oss-\(region).aliyuncs.com"
                print("Connecting to region: \(region), endpoint: \(defaultEndpoint)")

                let config = OSSConfiguration(
                    name: "Test",
                    accessKeyId: accessKeyId,
                    accessKeySecret: accessKeySecret,
                    region: region,
                    endpoint: defaultEndpoint
                )

                try await ossService.connect(with: config)
                buckets = try await ossService.listBuckets()

                await MainActor.run {
                    isLoading = false
                    isConnected = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true

                    // 在控制台打印详细错误
                    print("Connection error: \(error)")
                }
            }
        }
    }
}

#Preview {
    ConnectionTestView()
}
