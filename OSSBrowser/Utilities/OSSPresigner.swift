//
//  OSSPresigner.swift
//  OSSBrowser
//
//  共享的预签名 URL 生成，避免在预览、复制链接、QuickLook 等多处
//  重复构造 Client 与 presign 调用。
//

import Foundation
import AlibabaCloudOSS

enum OSSPresigner {
    /// 由配置构造一个 OSS Client
    static func makeClient(config: OSSConfiguration) -> Client {
        let ossConfig = Configuration.default()
            .withCredentialsProvider(StaticCredentialsProvider(
                accessKeyId: config.accessKeyId,
                accessKeySecret: config.accessKeySecret
            ))
            .withRegion(config.region)

        if let endpoint = config.endpoint {
            ossConfig.withEndpoint(endpoint)
        }
        return Client(ossConfig)
    }

    /// 生成预签名地址字符串
    /// - Parameter expiresIn: 有效期（秒），默认 1 小时
    static func presignedURLString(
        bucket: String,
        key: String,
        config: OSSConfiguration,
        expiresIn: TimeInterval = 3600
    ) async throws -> String {
        let client = makeClient(config: config)
        let result = try await client.presign(
            GetObjectRequest(bucket: bucket, key: key),
            Date().addingTimeInterval(expiresIn)
        )
        return result.url
    }

    /// 生成预签名 URL
    static func presignedURL(
        bucket: String,
        key: String,
        config: OSSConfiguration,
        expiresIn: TimeInterval = 3600
    ) async throws -> URL {
        let urlString = try await presignedURLString(
            bucket: bucket, key: key, config: config, expiresIn: expiresIn)
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "OSSPresigner",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法解析预签名地址"]
            )
        }
        return url
    }
}
