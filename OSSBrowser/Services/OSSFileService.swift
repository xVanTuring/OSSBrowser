//
//  OSSFileService.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import Foundation
import AlibabaCloudOSS
import Combine

@MainActor
class OSSFileService: ObservableObject {
    private let config: OSSConfiguration
    private let bucketName: String
    private var client: Client?

    @Published var currentPath: String = ""
    @Published var files: [OSSFile] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    init(config: OSSConfiguration, bucketName: String) {
        self.config = config
        self.bucketName = bucketName
        setupClient()
    }

    private func setupClient() {
        let ossConfig = Configuration.default()
            .withCredentialsProvider(StaticCredentialsProvider(
                accessKeyId: config.accessKeyId,
                accessKeySecret: config.accessKeySecret
            ))
            .withRegion(config.region)

        if let endpoint = config.endpoint {
            client = Client(ossConfig.withEndpoint(endpoint))
        } else {
            client = Client(ossConfig)
        }
    }

    func listFiles(at path: String = "") async throws {
        currentPath = path
        isLoading = true
        error = nil

        defer {
            isLoading = false
        }

        guard let client = client else {
            throw OSSError.clientNotInitialized
        }

        var fileList: [OSSFile] = []

        // 获取文件列表
        let prefix = path.isEmpty ? "" : path
        let delimiter = "/"

        let result = try await client.listObjectsV2(ListObjectsV2Request(
            bucket: bucketName,
            delimiter: delimiter,
            prefix: prefix
        ))

        // 处理文件
        if let objects = result.contents {
            for object in objects {
                let key = object.key ?? ""
                // 跳过目录标记（以 / 结尾）
                if !key.hasSuffix("/") && key != prefix {
                    let file = OSSFile(
                        key: key,
                        size: Int64(object.size ?? 0),
                        lastModified: object.lastModified ?? Date(),
                        eTag: object.etag ?? "",
                        storageClass: object.storageClass ?? "Standard",
                        isDirectory: false
                    )
                    fileList.append(file)
                }
            }
        }

        // 处理目录（CommonPrefixes）
        if let commonPrefixes = result.commonPrefixes {
            for prefix in commonPrefixes {
                if let prefixValue = prefix.prefix {
                    let dirName = prefixValue.replacingOccurrences(of: path, with: "")
                        .trimmingCharacters(in: ["/"])

                    if !dirName.isEmpty {
                        let directory = OSSFile(
                            key: prefixValue,
                            size: 0,
                            lastModified: Date(),
                            eTag: "",
                            storageClass: "",
                            isDirectory: true
                        )
                        fileList.append(directory)
                    }
                }
            }
        }

        // 排序：目录在前，文件在后，都按名称排序
        files = fileList.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }

    func changeDirectory(_ file: OSSFile) async throws {
        if file.isDirectory {
            try await listFiles(at: file.path)
        }
    }

    func goBack() async throws {
        if currentPath.isEmpty {
            return
        }

        let parentPath: String
        if currentPath.isEmpty {
            parentPath = ""
        } else {
            parentPath = URL(fileURLWithPath: currentPath)
                .deletingLastPathComponent()
                .path
        }
        try await listFiles(at: parentPath)
    }

    func createDirectory(name: String) async throws {
        guard let client = client else {
            throw OSSError.clientNotInitialized
        }

        let directoryKey = currentPath.isEmpty ? "\(name)/" : "\(currentPath)\(name)/"

        // 创建一个空对象表示目录
        let result = try await client.putObject(PutObjectRequest(
            bucket: bucketName,
            key: directoryKey,
            body: .data(Data())
        ))

        print("Create directory result: \(result.requestId)")
        try await listFiles(at: currentPath)
    }
}