//
//  UploadManager.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/10.
//

import Foundation
import AlibabaCloudOSS
import Combine

@MainActor
class UploadManager: ObservableObject {
    static let shared = UploadManager()

    @Published var uploadTasks: [UploadTask] = []

    var onUploadComplete: (() -> Void)?

    private var client: Client?
    private var config: OSSConfiguration?
    private var bucketName: String?

    private var activeUploads: Set<UUID> = []
    private var taskHandles: [UUID: Task<Void, Never>] = [:]
    private let maxConcurrentTasks = 5

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

    // MARK: - Public API

    func uploadFile(_ url: URL, to remotePath: String, in bucket: String) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes?[.size] as? Int64 ?? 0

        let task = UploadTask(
            fileName: url.lastPathComponent,
            localPath: url.path,
            remotePath: remotePath,
            fileSize: fileSize
        )

        uploadTasks.append(task)
        processQueue(bucket: bucket)
    }

    func uploadFolder(_ url: URL, to remotePath: String, in bucket: String) {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var folderTasks: [UploadTask] = []

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                let isDirectory = resourceValues.isDirectory ?? false
                if isDirectory { continue }

                let fileSize = Int64(resourceValues.fileSize ?? 0)
                let relativePath = fileURL.path.replacingOccurrences(of: url.path + "/", with: "")
                let remoteFilePath = remotePath.isEmpty ? relativePath : "\(remotePath)/\(relativePath)"

                folderTasks.append(UploadTask(
                    fileName: fileURL.lastPathComponent,
                    localPath: fileURL.path,
                    remotePath: remoteFilePath,
                    fileSize: fileSize
                ))
            } catch {
                print("Error getting file info: \(error)")
            }
        }

        folderTasks.sort { $0.localPath < $1.localPath }
        uploadTasks.append(contentsOf: folderTasks)
        processQueue(bucket: bucket)
    }

    func cancelUpload(_ task: UploadTask) {
        if let handle = taskHandles[task.id] {
            handle.cancel()
            taskHandles.removeValue(forKey: task.id)
        }
        task.status = .cancelled
        activeUploads.remove(task.id)
        if let bucket = bucketName {
            processQueue(bucket: bucket)
        }
    }

    func removeTask(_ task: UploadTask) {
        // 若正在上传，先取消
        if activeUploads.contains(task.id) {
            cancelUpload(task)
        }
        uploadTasks.removeAll { $0.id == task.id }
    }

    func clearCompletedTasks() {
        uploadTasks.removeAll { task in
            task.status == .completed || task.status == .cancelled
        }
    }

    func retryFailedTask(_ task: UploadTask) {
        guard let bucket = bucketName else { return }
        guard task.status == .failed else { return }

        task.status = .pending
        task.error = nil
        task.uploadedBytes = 0
        task.progress = 0.0
        task.completedParts = 0
        task.startTime = nil
        task.endTime = nil
        processQueue(bucket: bucket)
    }

    func getUploadProgress() -> (total: Int, completed: Int, uploading: Int, failed: Int) {
        var completed = 0
        var uploading = 0
        var failed = 0
        for task in uploadTasks {
            switch task.status {
            case .completed: completed += 1
            case .uploading: uploading += 1
            case .failed: failed += 1
            case .pending, .cancelled: break
            }
        }
        return (uploadTasks.count, completed, uploading, failed)
    }

    // MARK: - Queue

    private func processQueue(bucket: String) {
        let pendingTasks = uploadTasks.filter { $0.status == .pending }
        let availableSlots = maxConcurrentTasks - activeUploads.count
        let tasksToStart = Array(pendingTasks.prefix(availableSlots))

        for task in tasksToStart {
            startUpload(task, bucket: bucket)
        }
    }

    private func startUpload(_ task: UploadTask, bucket: String) {
        guard let client = client else { return }

        activeUploads.insert(task.id)
        task.status = .uploading
        task.startTime = Date()

        let settings = UploadSettings.shared.snapshot()
        let runner = UploadRunner(
            client: client,
            task: task,
            bucket: bucket,
            settings: settings
        )

        let handle = Task { [weak self] in
            let result = await runner.run()
            await MainActor.run {
                guard let self = self else { return }
                self.handleCompletion(task: task, result: result, bucket: bucket)
            }
        }
        taskHandles[task.id] = handle
    }

    private func handleCompletion(task: UploadTask, result: UploadRunner.Outcome, bucket: String) {
        taskHandles.removeValue(forKey: task.id)
        task.endTime = Date()

        switch result {
        case .success:
            task.status = .completed
            task.progress = 1.0
            task.uploadedBytes = task.fileSize
            task.completedParts = task.totalParts
            onUploadComplete?()
        case .cancelled:
            if task.status != .cancelled {
                task.status = .cancelled
            }
        case .failed(let error):
            task.error = error
            task.status = .failed
            print("Upload failed: \(task.fileName), error: \(error.localizedDescription)")
        }

        activeUploads.remove(task.id)
        processQueue(bucket: bucket)
    }
}

// MARK: - Upload Runner

nonisolated struct UploadRunner {
    enum Outcome {
        case success
        case cancelled
        case failed(Error)
    }

    let client: Client
    let task: UploadTask
    let bucket: String
    let settings: UploadSettings.Snapshot

    func run() async -> Outcome {
        let localURL = URL(fileURLWithPath: task.localPath)
        let fileSize = task.fileSize

        let useMultipart = fileSize >= settings.multipartThreshold && fileSize > 0
        let partSize = useMultipart ? settings.partSize : fileSize
        let totalParts: Int
        if fileSize == 0 {
            totalParts = 1
        } else {
            totalParts = Int((fileSize + partSize - 1) / partSize)
        }

        let remotePath = task.remotePath
        await MainActor.run { [task] in
            task.partSize = partSize
            task.totalParts = totalParts
            task.completedParts = 0
        }

        if !useMultipart {
            return await runSingle(url: localURL, fileSize: fileSize, remotePath: remotePath)
        }
        return await runMultipart(
            url: localURL,
            fileSize: fileSize,
            partSize: partSize,
            totalParts: totalParts,
            remotePath: remotePath
        )
    }

    // MARK: Single upload

    private func runSingle(url: URL, fileSize: Int64, remotePath: String) async -> Outcome {
        let counter = TransferByteCounter()
        let ticker = Self.makeTicker(task: task, counter: counter, totalSize: fileSize)
        await ticker.start()
        defer { Task { await ticker.stop() } }

        var request = PutObjectRequest(
            bucket: bucket,
            key: remotePath,
            body: .file(url)
        )
        request.progress = ProgressClosure { bytesIncrement, _, _ in
            counter.add(bytesIncrement)
        }

        do {
            _ = try await client.putObject(request)
            try Task.checkCancellation()
            await ticker.stop()
            return .success
        } catch is CancellationError {
            await ticker.stop()
            return .cancelled
        } catch {
            await ticker.stop()
            return .failed(error)
        }
    }

    // MARK: Multipart upload

    private func runMultipart(
        url: URL,
        fileSize: Int64,
        partSize: Int64,
        totalParts: Int,
        remotePath: String
    ) async -> Outcome {
        // 1. Initiate
        let uploadId: String
        do {
            let initResult = try await client.initiateMultipartUpload(
                InitiateMultipartUploadRequest(bucket: bucket, key: remotePath)
            )
            guard let id = initResult.uploadId else {
                return .failed(NSError(
                    domain: "UploadManager",
                    code: -20,
                    userInfo: [NSLocalizedDescriptionKey: "Missing uploadId"]
                ))
            }
            uploadId = id
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed(error)
        }

        let counter = TransferByteCounter()
        let ticker = Self.makeTicker(task: task, counter: counter, totalSize: fileSize)
        await ticker.start()

        // 2. Upload parts concurrently
        var uploadedParts: [Int: UploadPart] = [:]

        do {
            try await withThrowingTaskGroup(of: (Int, UploadPart).self) { group in
                var nextIndex = 0
                let concurrency = max(1, settings.maxConcurrency)

                while nextIndex < totalParts && nextIndex < concurrency {
                    let idx = nextIndex
                    group.addTask { [client, settings, bucket, remotePath] in
                        let part = try await Self.uploadOnePart(
                            index: idx,
                            fileURL: url,
                            partSize: partSize,
                            totalSize: fileSize,
                            bucket: bucket,
                            key: remotePath,
                            uploadId: uploadId,
                            client: client,
                            counter: counter,
                            maxRetry: settings.maxPartRetry
                        )
                        return (idx, part)
                    }
                    nextIndex += 1
                }

                while let (idx, part) = try await group.next() {
                    uploadedParts[idx] = part
                    await MainActor.run { [task] in
                        task.completedParts = min(task.completedParts + 1, task.totalParts)
                    }
                    if nextIndex < totalParts {
                        let next = nextIndex
                        group.addTask { [client, settings, bucket, remotePath] in
                            let part = try await Self.uploadOnePart(
                                index: next,
                                fileURL: url,
                                partSize: partSize,
                                totalSize: fileSize,
                                bucket: bucket,
                                key: remotePath,
                                uploadId: uploadId,
                                client: client,
                                counter: counter,
                                maxRetry: settings.maxPartRetry
                            )
                            return (next, part)
                        }
                        nextIndex += 1
                    }
                }
            }
        } catch is CancellationError {
            await ticker.stop()
            await Self.tryAbort(client: client, bucket: bucket, key: remotePath, uploadId: uploadId)
            return .cancelled
        } catch {
            await ticker.stop()
            await Self.tryAbort(client: client, bucket: bucket, key: remotePath, uploadId: uploadId)
            return .failed(error)
        }

        await ticker.stop()

        // 3. Complete
        let sortedParts = (0..<totalParts).compactMap { uploadedParts[$0] }
        do {
            _ = try await client.completeMultipartUpload(
                CompleteMultipartUploadRequest(
                    bucket: bucket,
                    key: remotePath,
                    uploadId: uploadId,
                    completeMultipartUpload: CompleteMultipartUpload(parts: sortedParts)
                )
            )
            return .success
        } catch is CancellationError {
            await Self.tryAbort(client: client, bucket: bucket, key: remotePath, uploadId: uploadId)
            return .cancelled
        } catch {
            await Self.tryAbort(client: client, bucket: bucket, key: remotePath, uploadId: uploadId)
            return .failed(error)
        }
    }

    // MARK: - Helpers

    private static func makeTicker(
        task: UploadTask,
        counter: TransferByteCounter,
        totalSize: Int64
    ) -> TransferProgressTicker {
        TransferProgressTicker(counter: counter) { [task] current in
            await MainActor.run {
                task.uploadedBytes = current
                if totalSize > 0 {
                    task.progress = min(1.0, Double(current) / Double(totalSize))
                }
            }
        }
    }

    private static func uploadOnePart(
        index: Int,
        fileURL: URL,
        partSize: Int64,
        totalSize: Int64,
        bucket: String,
        key: String,
        uploadId: String,
        client: Client,
        counter: TransferByteCounter,
        maxRetry: Int
    ) async throws -> UploadPart {
        let start = Int64(index) * partSize
        let end = min(start + partSize, totalSize)
        let currentSize = end - start
        let partNumber = index + 1

        // 读分片内容（在后台线程做磁盘 I/O，不阻塞 MainActor）
        let partData = try readFileRange(url: fileURL, offset: UInt64(start), length: Int(currentSize))

        var attempt = 0
        var lastError: Error?

        while attempt <= maxRetry {
            try Task.checkCancellation()

            // 本次尝试的字节计数器；失败时从全局 counter 回滚
            let attemptCounter = TransferByteCounter()

            do {
                var request = UploadPartRequest(
                    bucket: bucket,
                    key: key,
                    partNumber: partNumber,
                    uploadId: uploadId,
                    body: .data(partData)
                )
                request.progress = ProgressClosure { bytesIncrement, _, _ in
                    attemptCounter.add(bytesIncrement)
                    counter.add(bytesIncrement)
                }

                let result = try await client.uploadPart(request)
                try Task.checkCancellation()

                return UploadPart(etag: result.etag, partNumber: partNumber)
            } catch is CancellationError {
                // 取消不算失败，但本次 attempt 发出去的字节也回滚
                counter.add(-attemptCounter.total)
                throw CancellationError()
            } catch {
                // 回滚本次尝试的字节
                counter.add(-attemptCounter.total)
                lastError = error
                attempt += 1
                if attempt > maxRetry { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        throw lastError ?? NSError(
            domain: "UploadManager",
            code: -21,
            userInfo: [NSLocalizedDescriptionKey: "Part \(partNumber) failed after retries"]
        )
    }

    private static func readFileRange(url: URL, offset: UInt64, length: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: offset)
        if #available(macOS 13.0, *) {
            return try handle.read(upToCount: length) ?? Data()
        } else {
            return handle.readData(ofLength: length)
        }
    }

    private static func tryAbort(client: Client, bucket: String, key: String, uploadId: String) async {
        do {
            _ = try await client.abortMultipartUpload(
                AbortMultipartUploadRequest(
                    bucket: bucket,
                    key: key,
                    uploadId: uploadId
                )
            )
        } catch {
            print("Abort multipart upload failed (will be cleaned up by OSS lifecycle): \(error)")
        }
    }
}
