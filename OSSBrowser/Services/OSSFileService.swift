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

    // 导航栈
    private var backStack: [String] = []  // 可以后退的路径
    private var forwardStack: [String] = []  // 可以前进的路径

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

    func listFiles(at path: String = "", addToHistory: Bool = true) async throws {
        // 如果是新的导航（不是通过前进/后退），需要更新栈
        if addToHistory && path != currentPath {
            // 将当前路径推入后退栈
            backStack.append(currentPath)
            // 清空前进栈，因为这是新的导航
            forwardStack.removeAll()
        }

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
        // 注意：OSS 的 prefix 需要以 / 结尾来表示目录
        var prefix = path.isEmpty ? "" : path
        if !prefix.isEmpty && !prefix.hasSuffix("/") {
            prefix += "/"
        }
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
            for cp in commonPrefixes {
                if let prefixValue = cp.prefix {
                    // 移除当前路径前缀，获取相对目录名
                    let relativePath = prefixValue.replacingOccurrences(of: prefix, with: "")
                        .trimmingCharacters(in: ["/"])

                    if !relativePath.isEmpty {
                        let directory = OSSFile(
                            key: prefixValue.trimmingCharacters(in: ["/"]),
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
        // 检查是否可以后退
        guard let previousPath = backStack.popLast() else {
            throw OSSError.alreadyAtRoot
        }

        // 将当前路径推入前进栈
        forwardStack.append(currentPath)

        // 切换到上一个路径
        try await listFiles(at: previousPath, addToHistory: false)
    }

    func goForward() async throws {
        // 检查是否可以前进
        guard let nextPath = forwardStack.popLast() else {
            // 没有可以前进的路径
            return
        }

        // 将当前路径推入后退栈
        backStack.append(currentPath)

        // 切换到下一个路径
        try await listFiles(at: nextPath, addToHistory: false)
    }

    // 检查是否可以返回
    var canGoBack: Bool {
        return !backStack.isEmpty
    }

    // 检查是否可以前进
    var canGoForward: Bool {
        return !forwardStack.isEmpty
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

    func deleteFile(_ file: OSSFile) async throws {
        guard let client = client else {
            throw OSSError.clientNotInitialized
        }

        if file.isDirectory {
            // 删除文件夹 - 需要删除所有子文件和子文件夹
            try await deleteDirectory(file.key)
        } else {
            // 删除单个文件
            let result = try await client.deleteObject(DeleteObjectRequest(
                bucket: bucketName,
                key: file.key
            ))
            print("Delete file result: \(result.requestId)")
        }
    }

    private func deleteDirectory(_ directoryKey: String) async throws {
        guard let client = client else {
            throw OSSError.clientNotInitialized
        }

        // 获取文件夹中的所有文件
        let listResult = try await client.listObjectsV2(ListObjectsV2Request(
            bucket: bucketName,
            prefix: directoryKey
        ))

        // 逐个删除所有文件
        if let objects = listResult.contents {
            for object in objects {
                let result = try await client.deleteObject(DeleteObjectRequest(
                    bucket: bucketName,
                    key: object.key
                ))
                print("Delete object result: \(result.requestId)")
            }
        }

        // 如果文件夹本身也是一个对象（如空文件夹），也需要删除
        let _ = try await client.deleteObject(DeleteObjectRequest(
            bucket: bucketName,
            key: directoryKey
        ))
    }

    // MARK: - Upload Methods

    func uploadFile(_ url: URL) {
        // 配置上传管理器
        UploadManager.shared.configure(with: config, bucketName: bucketName)

        // 构建远程路径
        let remotePath = currentPath.isEmpty ? url.lastPathComponent : "\(currentPath)/\(url.lastPathComponent)"

        UploadManager.shared.uploadFile(url, to: remotePath, in: bucketName)
    }

    func uploadFolder(_ url: URL) {
        // 配置上传管理器
        UploadManager.shared.configure(with: config, bucketName: bucketName)

        // 构建远程路径
        let remotePath = currentPath.isEmpty ? url.lastPathComponent : "\(currentPath)/\(url.lastPathComponent)"

        UploadManager.shared.uploadFolder(url, to: remotePath, in: bucketName)
    }

    func getFullRemotePath(for fileName: String) -> String {
        return currentPath.isEmpty ? fileName : "\(currentPath)/\(fileName)"
    }
}
