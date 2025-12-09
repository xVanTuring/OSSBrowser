//
//  OSSService.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import Foundation
import AlibabaCloudOSS
import Combine

@MainActor
class OSSService: ObservableObject {
    private var client: Client?

    func connect(with config: OSSConfiguration) async throws {
        print("Starting OSS connection...")
        print("Region: \(config.region)")

        // 创建配置
        var ossConfig = Configuration.default()
            .withCredentialsProvider(StaticCredentialsProvider(
                accessKeyId: config.accessKeyId,
                accessKeySecret: config.accessKeySecret
            ))
            .withRegion(config.region)

        // 如果指定了 endpoint，使用自定义 endpoint
        if let endpoint = config.endpoint {
            print("Using endpoint: \(endpoint)")
            ossConfig = ossConfig.withEndpoint(endpoint)
        }

        // 创建客户端
        client = Client(ossConfig)
        print("OSS client created")

        // 先测试一个简单的请求 - GetService (ListBuckets)
        do {
            print("Attempting to list buckets...")
            let result = try await client!.listBuckets(ListBucketsRequest())
            print("Connect success, requestId: \(result.requestId)")
            print("Buckets count: \(result.buckets?.count ?? 0)")
        } catch {
            // 打印详细错误信息
            print("Error occurred: \(error)")
            if let ossError = error as? ClientError {
                print("OSS Error Code: \(ossError.code)")
                print("OSS Error Message: \(ossError.message)")
                print("OSS Error Description: \(ossError.localizedDescription)")

                // 尝试获取更多错误信息
//                if let underlyingError = ossError.underlying {
//                    print("Underlying error: \(underlyingError)")
//                }

                throw OSSError.ossError(code: ossError.code, message: ossError.message)
            } else {
                print("Unknown error type: \(type(of: error))")
                print("Error details: \(error.localizedDescription)")
                throw error
            }
        }
    }

    func listBuckets() async throws -> [BucketItem] {
        guard let client = client else {
            throw OSSError.clientNotInitialized
        }

        var buckets: [BucketItem] = []

        for try await result in client.listBucketsPaginator(ListBucketsRequest()) {
            if let bucketList = result.buckets {
                for bucket in bucketList {
                    if let name = bucket.name,
                       let region = bucket.region,
                       let creationDate = bucket.creationDate {
                        buckets.append(BucketItem(
                            name: name,
                            region: region,
                            creationDate: creationDate,
                            storageClass: bucket.storageClass ?? "Standard"
                        ))
                    }
                }
            }
        }

        return buckets
    }
}

enum OSSError: LocalizedError {
    case clientNotInitialized
    case invalidCredentials
    case networkError
    case ossError(code: String?, message: String?)

    var errorDescription: String? {
        switch self {
        case .clientNotInitialized:
            return "OSS客户端未初始化"
        case .invalidCredentials:
            return "无效的凭证"
        case .networkError:
            return "网络连接错误"
        case .ossError(let code, let message):
            if let code = code, let message = message {
                return "OSS错误 [\(code)]: \(message)"
            } else if let message = message {
                return "OSS错误: \(message)"
            } else {
                return "OSS连接失败"
            }
        }
    }
}

struct BucketItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let region: String
    let creationDate: Date
    let storageClass: String
}
