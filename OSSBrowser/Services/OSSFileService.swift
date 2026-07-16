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
    @Published var isLoadingMore: Bool = false
    @Published var hasMore: Bool = false
    @Published var currentSearchQuery: String = ""
    @Published var error: Error?

    private var nextContinuationToken: String? = nil
    private let pageSize: Int = 200

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

    private func buildPrefix(for path: String) -> String {
        var prefix = path.isEmpty ? "" : path
        if !prefix.isEmpty && !prefix.hasSuffix("/") {
            prefix += "/"
        }
        return prefix
    }

    private func processListResult(
        _ result: ListObjectsV2Result,
        prefix: String,
        directorySet: inout Set<String>
    ) -> [OSSFile] {
        var fileList: [OSSFile] = []

        if let objects = result.contents {
            for object in objects {
                let key = object.key ?? ""
                if !key.hasSuffix("/") && key != prefix {
                    fileList.append(OSSFile(
                        key: key,
                        size: Int64(object.size ?? 0),
                        lastModified: object.lastModified ?? Date(),
                        eTag: object.etag ?? "",
                        storageClass: object.storageClass ?? "Standard",
                        isDirectory: false
                    ))
                }
            }
        }

        if let commonPrefixes = result.commonPrefixes {
            for cp in commonPrefixes {
                if let prefixValue = cp.prefix {
                    let relativePath = prefixValue
                        .replacingOccurrences(of: prefix, with: "")
                        .trimmingCharacters(in: ["/"])
                    if !relativePath.isEmpty && !directorySet.contains(prefixValue) {
                        directorySet.insert(prefixValue)
                        fileList.append(OSSFile(
                            key: prefixValue.trimmingCharacters(in: ["/"]),
                            size: 0,
                            lastModified: Date(),
                            eTag: "",
                            storageClass: "",
                            isDirectory: true
                        ))
                    }
                }
            }
        }

        return fileList
    }

    private func sortFiles(_ fileList: [OSSFile]) -> [OSSFile] {
        fileList.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }

    func listFiles(at path: String = "", addToHistory: Bool = true) async throws {
        // 如果是新的导航（不是通过前进/后退），需要更新栈
        if addToHistory && path != currentPath {
            backStack.append(currentPath)
            forwardStack.removeAll()
        }

        currentPath = path
        currentSearchQuery = ""
        isLoading = true
        error = nil
        nextContinuationToken = nil
        hasMore = false

        defer { isLoading = false }

        try await fetchFiles(dirPrefix: buildPrefix(for: path), searchQuery: "")
    }

    func search(_ query: String) async throws {
        guard !isLoading else { return }

        currentSearchQuery = query
        isLoading = true
        error = nil
        nextContinuationToken = nil
        hasMore = false

        defer { isLoading = false }

        try await fetchFiles(dirPrefix: buildPrefix(for: currentPath), searchQuery: query)
    }

    private func fetchFiles(dirPrefix: String, searchQuery: String) async throws {
        guard let client = client else {
            throw OSSError.clientNotInitialized
        }

        // 搜索时 prefix = 目录前缀 + 搜索词，不带 delimiter 可跨子目录匹配
        // 搜索时保留 delimiter 只匹配当前目录层级
        let requestPrefix = dirPrefix + searchQuery
        var directorySet = Set<String>()

        let result = try await client.listObjectsV2(ListObjectsV2Request(
            bucket: bucketName,
            delimiter: "/",
            maxKeys: pageSize,
            prefix: requestPrefix
        ))

        let fileList = processListResult(result, prefix: dirPrefix, directorySet: &directorySet)
        nextContinuationToken = result.nextContinuationToken
        hasMore = result.isTruncated ?? false

        files = sortFiles(fileList)
    }

    func loadMoreFiles() async throws {
        guard hasMore, let token = nextContinuationToken, !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        guard let client = client else {
            throw OSSError.clientNotInitialized
        }

        let dirPrefix = buildPrefix(for: currentPath)
        let requestPrefix = dirPrefix + currentSearchQuery
        var directorySet = Set<String>(
            files.filter { $0.isDirectory }.map {
                $0.key.hasSuffix("/") ? $0.key : "\($0.key)/"
            }
        )

        let result = try await client.listObjectsV2(ListObjectsV2Request(
            bucket: bucketName,
            delimiter: "/",
            maxKeys: pageSize,
            prefix: requestPrefix,
            continuationToken: token
        ))

        let newFiles = processListResult(result, prefix: dirPrefix, directorySet: &directorySet)
        nextContinuationToken = result.nextContinuationToken
        hasMore = result.isTruncated ?? false

        files = sortFiles(files + newFiles)
    }

    /// 检查某个目录路径下是否仍存在对象（用于校验收藏路径是否已被删除）
    func checkPathExists(_ path: String) async throws -> Bool {
        guard let client = client else {
            throw OSSError.clientNotInitialized
        }
        guard !path.isEmpty else { return true }

        let result = try await client.listObjectsV2(ListObjectsV2Request(
            bucket: bucketName,
            maxKeys: 1,
            prefix: buildPrefix(for: path)
        ))
        return !(result.contents?.isEmpty ?? true)
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

        let directoryKey = currentPath.isEmpty ? "\(name)/" : "\(currentPath)/\(name)/"

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

    func deleteFiles(_ files: [OSSFile]) async throws {
        guard let client = client else {
            throw OSSError.clientNotInitialized
        }

        // 批量删除文件
        for file in files {
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
    }

    private func deleteDirectory(_ directoryKey: String) async throws {
        guard let client = client else {
            throw OSSError.clientNotInitialized
        }

        // 使用分页器获取文件夹中的所有文件
        for try await result in client.listObjectsV2Paginator(ListObjectsV2Request(
            bucket: bucketName,
            prefix: directoryKey
        )) {
            // 逐个删除所有文件
            if let objects = result.contents {
                for object in objects {
                    let deleteResult = try await client.deleteObject(DeleteObjectRequest(
                        bucket: bucketName,
                        key: object.key
                    ))
                    print("Delete object result: \(deleteResult.requestId)")
                }
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

    // MARK: - Rename Methods
    func renameFile(_ file: OSSFile, newName: String) async throws {
        guard let client = client else {
            throw OSSError.clientNotInitialized
        }

        let trimmedNewName = newName.trimmingCharacters(in: ["/"])
        guard !trimmedNewName.isEmpty,
              !trimmedNewName.contains("/"),
              trimmedNewName != file.name else {
            throw NSError(
                domain: "OSSFileService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "无效的新名称"]
            )
        }

        // 计算所在目录（不含末尾 /）
        let parentDir: String = {
            let components = file.key.split(separator: "/", omittingEmptySubsequences: true)
            guard components.count > 1 else { return "" }
            return components.dropLast().joined(separator: "/")
        }()

        if file.isDirectory {
            // 文件夹：遍历旧前缀下所有对象，逐个复制到新前缀后删除原对象
            let oldPrefix = file.key.hasSuffix("/") ? file.key : "\(file.key)/"
            let newDirKey = parentDir.isEmpty ? trimmedNewName : "\(parentDir)/\(trimmedNewName)"
            let newPrefix = "\(newDirKey)/"

            for try await result in client.listObjectsV2Paginator(ListObjectsV2Request(
                bucket: bucketName,
                prefix: oldPrefix
            )) {
                guard let objects = result.contents else { continue }
                for object in objects {
                    guard let sourceKey = object.key else { continue }
                    let suffix = String(sourceKey.dropFirst(oldPrefix.count))
                    let destKey = "\(newPrefix)\(suffix)"

                    _ = try await client.copyObject(CopyObjectRequest(
                        bucket: bucketName,
                        key: destKey,
                        sourceBucket: bucketName,
                        sourceKey: sourceKey
                    ))
                    _ = try await client.deleteObject(DeleteObjectRequest(
                        bucket: bucketName,
                        key: sourceKey
                    ))
                }
            }
        } else {
            // 文件：CopyObject + DeleteObject
            let newKey = parentDir.isEmpty ? trimmedNewName : "\(parentDir)/\(trimmedNewName)"

            _ = try await client.copyObject(CopyObjectRequest(
                bucket: bucketName,
                key: newKey,
                sourceBucket: bucketName,
                sourceKey: file.key
            ))
            _ = try await client.deleteObject(DeleteObjectRequest(
                bucket: bucketName,
                key: file.key
            ))
        }

        try await listFiles(at: currentPath, addToHistory: false)
    }
}
