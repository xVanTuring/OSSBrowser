//
//  UploadManager.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/10.
//

import Foundation
import SwiftUI
import AlibabaCloudOSS
import Combine

// 上传任务状态
enum UploadStatus {
    case pending
    case uploading(progress: Double)
    case completed
    case failed(Error)
}

// 上传任务模型
class UploadTask: ObservableObject, Identifiable {
    let id = UUID()
    let fileName: String
    let localPath: String
    let remotePath: String
    let fileSize: Int64
    let isDirectory: Bool

    @Published var status: UploadStatus = .pending
    @Published var progress: Double = 0.0

    init(fileName: String, localPath: String, remotePath: String, fileSize: Int64, isDirectory: Bool = false) {
        self.fileName = fileName
        self.localPath = localPath
        self.remotePath = remotePath
        self.fileSize = fileSize
        self.isDirectory = isDirectory
    }
}

// 上传管理器
@MainActor
class UploadManager: ObservableObject {
    static let shared = UploadManager()

    private var client: Client?
    private var config: OSSConfiguration?
    private var bucketName: String?

    // 上传完成回调
    var onUploadComplete: (() -> Void)?

    // 当前上传任务
    @Published var uploadTasks: [UploadTask] = []

    // 并发控制
    private let maxConcurrentUploads = 5
    private var activeUploads = 0
    private var uploadQueue: [UploadTask] = []

    // 分片上传配置
    private let multipartThreshold: Int64 = 100 * 1024 * 1024 // 100MB
    private let partSize: Int64 = 100 * 1024 * 1024 // 10MB per part
    private let maxPartRetryAttempts = 3 // 每个分片最大重试次数

    // 存储分片上传的 uploadId
    private var multipartUploadIds: [String: String] = [:]

    private init() {}

    func configure(with config: OSSConfiguration, bucketName: String) {
        self.config = config
        self.bucketName = bucketName

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

    // 上传单个文件
    func uploadFile(_ url: URL, to remotePath: String, in bucket: String) {
        guard let client = client else { return }

        // 获取文件信息
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes?[.size] as? Int64 ?? 0

        // 创建上传任务
        let task = UploadTask(
            fileName: url.lastPathComponent,
            localPath: url.path,
            remotePath: remotePath,
            fileSize: fileSize
        )

        uploadTasks.append(task)

        // 添加到队列
        if activeUploads < maxConcurrentUploads {
            startUpload(task, client: client, bucket: bucket)
        } else {
            uploadQueue.append(task)
        }
    }

    // 上传文件夹
    func uploadFolder(_ url: URL, to remotePath: String, in bucket: String) {
        guard let enumerator = FileManager.default.enumerator(at: url,
                                                           includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                                                           options: [.skipsHiddenFiles]) else { return }

        var folderTasks: [UploadTask] = []

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                let isDirectory = resourceValues.isDirectory ?? false

                if !isDirectory {
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    // 获取相对于文件夹根目录的路径
                    let relativePath = fileURL.path.replacingOccurrences(of: url.path + "/", with: "")
                    // 如果 remotePath 为空，使用相对路径；否则组合
                    let remoteFilePath = remotePath.isEmpty ? relativePath : "\(remotePath)/\(relativePath)"

                    let task = UploadTask(
                        fileName: fileURL.lastPathComponent,
                        localPath: fileURL.path,
                        remotePath: remoteFilePath,
                        fileSize: fileSize
                    )

                    folderTasks.append(task)
                }
            } catch {
                print("Error getting file info: \(error)")
            }
        }

        // 按文件路径排序，确保上传顺序
        folderTasks.sort { $0.localPath < $1.localPath }

        uploadTasks.append(contentsOf: folderTasks)

        // 将文件夹任务添加到上传队列
        for task in folderTasks {
            if activeUploads < maxConcurrentUploads {
                startUpload(task, client: client!, bucket: bucket)
            } else {
                uploadQueue.append(task)
            }
        }
    }

    private func startUpload(_ task: UploadTask, client: Client, bucket: String) {
        guard activeUploads < maxConcurrentUploads else { return }

        activeUploads += 1
        task.status = .uploading(progress: 0.0)

        Task { @MainActor in
            do {
                // 根据文件大小选择上传方式
                if task.fileSize >= multipartThreshold {
                    try await uploadLargeFile(task: task, client: client, bucket: bucket)
                } else {
                    try await uploadSmallFile(task: task, client: client, bucket: bucket)
                }

                // 上传完成后触发回调
                onUploadComplete?()

            } catch {
                task.status = .failed(error)
                print("Upload failed: \(task.fileName), Error: \(error)")

                // 强制刷新 UI
                self.objectWillChange.send()
            }

            activeUploads -= 1

            // 处理队列中的下一个任务
            if !uploadQueue.isEmpty {
                let nextTask = uploadQueue.removeFirst()
                startUpload(nextTask, client: client, bucket: bucket)
            }
        }
    }

    // 小文件直接上传
    private func uploadSmallFile(task: UploadTask, client: Client, bucket: String) async throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: task.localPath))
        var request = PutObjectRequest(
            bucket: bucket,
            key: task.remotePath,
            body: .data(data)
        )

        // 设置上传进度回调
        request.progress = ProgressClosure{ [weak task] bytesIncrement, totalBytesTransferred, totalBytesExpected in
            guard let task = task else { return }

            let progress = totalBytesExpected > 0 ? Double(totalBytesTransferred) / Double(totalBytesExpected) : 0.0

            Task { @MainActor in
                task.progress = progress
                task.status = .uploading(progress: progress)
                print("Upload progress for \(task.fileName): \(String(format: "%.1f%%", progress * 100))")
            }
        }

        let result = try await client.putObject(request)

        // 确保最终状态为完成
        task.status = .completed
        task.progress = 1.0
        print("Upload completed: \(task.fileName), RequestId: \(result.requestId)")

        // 强制刷新 UI
        self.objectWillChange.send()
    }

    // 大文件分片上传
    private func uploadLargeFile(task: UploadTask, client: Client, bucket: String) async throws {
        print("Starting multipart upload for \(task.fileName) (\(ByteCountFormatter.string(fromByteCount: task.fileSize, countStyle: .file)))")

        // 1. 初始化分片上传
        let initResult = try await client.initiateMultipartUpload(
            InitiateMultipartUploadRequest(
                bucket: bucket,
                key: task.remotePath
            )
        )

        let uploadId = initResult.uploadId
        multipartUploadIds[task.id.uuidString] = uploadId

        // 2. 计算分片数量
        let partCount = Int((task.fileSize + partSize - 1) / partSize)
        var parts: [UploadPart] = []
        var uploadedBytes: Int64 = 0

        // 3. 打开文件并准备上传分片
        guard let fileHandle = FileHandle(forReadingAtPath: task.localPath) else {
            throw NSError(domain: "UploadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot open file for reading"])
        }

        defer {
            fileHandle.closeFile()
        }

        // 4. 顺序上传分片（带重试机制）
        for partNumber in 1...partCount {
            var uploadSuccess = false
            var lastError: Error?

            // 读取分片数据（只需要读取一次）
            let offset = Int64((partNumber - 1)) * self.partSize
            fileHandle.seek(toFileOffset: UInt64(offset))
            let currentPartSize = min(self.partSize, task.fileSize - offset)
            let partData = fileHandle.readData(ofLength: Int(currentPartSize))

            // 重试循环
            for attempt in 1...maxPartRetryAttempts {
                do {
                    print("Uploading part \(partNumber) of \(task.fileName) (attempt \(attempt)/\(maxPartRetryAttempts))")

                    // 上传分片
                    let uploadPartResult = try await client.uploadPart(
                        UploadPartRequest(
                            bucket: bucket,
                            key: task.remotePath,
                            partNumber: partNumber,
                            uploadId: uploadId,
                            body: .data(partData)
                        )
                    )

                    let part = UploadPart(
                        etag: uploadPartResult.etag,
                        partNumber: partNumber
                    )

                    parts.append(part)
                    uploadedBytes += currentPartSize
                    uploadSuccess = true

                    // 更新进度
                    let progress = Double(partNumber) / Double(partCount)
                    Task { @MainActor in
                        task.progress = progress
                        task.status = .uploading(progress: progress)
                        print("Multipart upload progress for \(task.fileName): \(String(format: "%.1f%%", progress * 100)) (\(partNumber)/\(partCount) parts)")
                    }

                    break // 成功则退出重试循环

                } catch {
                    lastError = error
                    print("Upload part \(partNumber) failed (attempt \(attempt)/\(maxPartRetryAttempts)): \(error)")

                    if attempt < maxPartRetryAttempts {
                        // 等待一段时间再重试（指数退避）
                        let delay = pow(2.0, Double(attempt - 1)) // 1s, 2s, 4s
                        print("Retrying part \(partNumber) after \(delay) seconds...")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            }

            // 如果所有重试都失败，抛出错误
            if !uploadSuccess {
                let errorMessage = "Part \(partNumber) upload failed after \(maxPartRetryAttempts) attempts"
                print("\(errorMessage): \(lastError?.localizedDescription ?? "Unknown error")")
                throw NSError(domain: "UploadError", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: errorMessage,
                    NSUnderlyingErrorKey: lastError as Any
                ])
            }
        }

        // 5. 完成分片上传
        parts.sort { ($0.partNumber ?? 0) < ($1.partNumber ?? 0) }

        let _ = try await client.completeMultipartUpload(
            CompleteMultipartUploadRequest(
                bucket: bucket,
                key: task.remotePath,
                uploadId: uploadId,
                completeMultipartUpload: CompleteMultipartUpload(parts: parts)
            )
        )

        // 清理 uploadId
        multipartUploadIds.removeValue(forKey: task.id.uuidString)

        // 确保最终状态为完成
        task.status = .completed
        task.progress = 1.0
        print("Multipart upload completed: \(task.fileName)")

        // 强制刷新 UI
        self.objectWillChange.send()
    }

    private func processQueue(client: Client, bucket: String) {
        while activeUploads < maxConcurrentUploads && !uploadQueue.isEmpty {
            let task = uploadQueue.removeFirst()
            startUpload(task, client: client, bucket: bucket)
        }
    }

    // 清除已完成的任务
    func clearCompletedTasks() {
        uploadTasks.removeAll { task in
            if case .completed = task.status {
                return true
            }
            return false
        }
    }

    // 重试失败的任务
    func retryFailedTask(_ task: UploadTask) {
        guard let client = client, let bucket = bucketName,
              case .failed = task.status else { return }

        task.status = .pending
        if activeUploads < maxConcurrentUploads {
            startUpload(task, client: client, bucket: bucket)
        } else {
            uploadQueue.append(task)
        }
    }

    // 取消上传任务
    func cancelUpload(_ task: UploadTask) async {
        guard let client = client, let bucket = bucketName else { return }

        // 如果是分片上传，需要取消 uploadId
        if let uploadId = multipartUploadIds[task.id.uuidString] {
            do {
                let _ = try await client.abortMultipartUpload(
                    AbortMultipartUploadRequest(
                        bucket: bucket,
                        key: task.remotePath,
                        uploadId: uploadId
                    )
                )
                multipartUploadIds.removeValue(forKey: task.id.uuidString)
                print("Multipart upload cancelled for \(task.fileName)")
            } catch {
                print("Failed to abort multipart upload: \(error)")
            }
        }

        // 从队列中移除
        uploadTasks.removeAll { $0.id == task.id }
        uploadQueue.removeAll { $0.id == task.id }
    }

    // 获取上传进度统计
    func getUploadProgress() -> (total: Int, completed: Int, uploading: Int, failed: Int) {
        var completed = 0
        var uploading = 0
        var failed = 0

        for task in uploadTasks {
            switch task.status {
            case .completed:
                completed += 1
            case .uploading:
                uploading += 1
            case .failed:
                failed += 1
            case .pending:
                break
            }
        }

        return (uploadTasks.count, completed, uploading, failed)
    }
}