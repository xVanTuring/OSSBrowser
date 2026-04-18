//
//  DownloadManager.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/10.
//

import Foundation
import AlibabaCloudOSS
import UserNotifications
import Combine

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var downloadTasks: [DownloadTask] = []

    private var client: Client?
    private var activeDownloads: Set<UUID> = []
    private var taskHandles: [UUID: Task<Void, Never>] = [:]
    private let maxConcurrentTasks = 5

    private let sessionDelegate = DownloadSessionDelegate()
    private let urlSession: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 10
        self.urlSession = URLSession(
            configuration: config,
            delegate: sessionDelegate,
            delegateQueue: nil
        )
        requestNotificationPermission()
    }

    func configure(with config: OSSConfiguration) {
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

    // MARK: - Public Methods

    func downloadFile(_ file: OSSFile, from bucket: String) {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let localURL = downloadsURL.appendingPathComponent(file.name)

        let task = DownloadTask(
            fileName: file.name,
            key: file.key,
            bucketName: bucket,
            totalSize: file.size,
            localURL: localURL
        )

        downloadTasks.append(task)
        processQueue()
    }

    func downloadFolder(_ folder: OSSFile, from bucket: String, files: [OSSFile]) {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let folderURL = downloadsURL.appendingPathComponent(folder.name)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            print("Failed to create directory: \(error)")
            return
        }

        let folderFiles = files.filter { $0.key.hasPrefix(folder.key) && !$0.isDirectory }
        for file in folderFiles {
            let relativePath = String(file.key.dropFirst(folder.key.count))
            let fileURL = folderURL.appendingPathComponent(relativePath)

            let parentDir = fileURL.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            } catch {
                print("Failed to create directory: \(error)")
                continue
            }

            let task = DownloadTask(
                fileName: relativePath,
                key: file.key,
                bucketName: bucket,
                totalSize: file.size,
                localURL: fileURL
            )
            downloadTasks.append(task)
        }

        processQueue()
    }

    func cancelDownload(_ taskId: UUID) {
        guard let task = downloadTasks.first(where: { $0.id == taskId }) else { return }

        if let handle = taskHandles[taskId] {
            handle.cancel()
            taskHandles.removeValue(forKey: taskId)
        }

        task.status = .cancelled
        activeDownloads.remove(taskId)
        processQueue()
    }

    func removeCompletedTasks() {
        downloadTasks.removeAll { task in
            task.status == .completed || task.status == .failed || task.status == .cancelled
        }
    }

    // MARK: - Queue

    private func processQueue() {
        let pendingTasks = downloadTasks.filter { $0.status == .pending }
        let availableSlots = maxConcurrentTasks - activeDownloads.count
        let tasksToStart = Array(pendingTasks.prefix(availableSlots))

        for task in tasksToStart {
            startDownload(task)
        }
    }

    private func startDownload(_ task: DownloadTask) {
        guard let client = client else { return }

        activeDownloads.insert(task.id)
        task.status = .downloading
        task.startTime = Date()

        let settings = DownloadSettings.shared.snapshot()
        let runner = DownloadRunner(
            client: client,
            urlSession: urlSession,
            sessionDelegate: sessionDelegate,
            task: task,
            settings: settings
        )

        let handle = Task { [weak self] in
            let result = await runner.run()
            await MainActor.run {
                guard let self = self else { return }
                self.handleCompletion(task: task, result: result)
            }
        }
        taskHandles[task.id] = handle
    }

    private func handleCompletion(task: DownloadTask, result: DownloadRunner.Outcome) {
        taskHandles.removeValue(forKey: task.id)
        task.endTime = Date()

        switch result {
        case .success:
            task.status = .completed
            task.progress = 1.0
            task.downloadedBytes = task.totalSize
            task.completedParts = task.totalParts
            sendNotification(title: "下载完成", body: "\(task.fileName) 下载完成")
        case .cancelled:
            if task.status != .cancelled {
                task.status = .cancelled
            }
        case .failed(let error):
            task.error = error
            task.status = .failed
            sendNotification(title: "下载失败", body: "\(task.fileName) 下载失败: \(error.localizedDescription)")
        }

        activeDownloads.remove(task.id)
        processQueue()
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Byte Counter

nonisolated final class DownloadByteCounter: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var _total: Int64 = 0

    func add(_ n: Int64) {
        lock.lock()
        _total += n
        lock.unlock()
    }

    var total: Int64 {
        lock.lock()
        let v = _total
        lock.unlock()
        return v
    }
}

// MARK: - File Writer Actor

actor DownloadFileWriter {
    private let handle: FileHandle
    private let tempURL: URL

    init(tempURL: URL, totalSize: Int64) throws {
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.removeItem(at: tempURL)
        }
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempURL)
        if totalSize > 0 {
            try handle.truncate(atOffset: UInt64(totalSize))
        }
        self.handle = handle
        self.tempURL = tempURL
    }

    func write(_ data: Data, at offset: UInt64) throws {
        try handle.seek(toOffset: offset)
        try handle.write(contentsOf: data)
    }

    func close() {
        try? handle.close()
    }

    func cleanup() {
        try? handle.close()
        try? FileManager.default.removeItem(at: tempURL)
    }
}

// MARK: - URLSession Delegate

nonisolated final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private struct PartRequest {
        let counter: DownloadByteCounter
        let continuation: CheckedContinuation<URL, Error>
        var persistedURL: URL?
        var moveError: Error?
    }

    private let lock = NSLock()
    nonisolated(unsafe) private var partRequests: [Int: PartRequest] = [:]

    func register(
        counter: DownloadByteCounter,
        continuation: CheckedContinuation<URL, Error>,
        for task: URLSessionTask
    ) {
        lock.lock()
        partRequests[task.taskIdentifier] = PartRequest(
            counter: counter,
            continuation: continuation,
            persistedURL: nil,
            moveError: nil
        )
        lock.unlock()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        lock.lock()
        let counter = partRequests[downloadTask.taskIdentifier]?.counter
        lock.unlock()
        counter?.add(bytesWritten)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // 必须在本方法返回前把文件搬走，否则系统会删除 tmp
        let persistedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("oss-part-\(UUID().uuidString)")
        do {
            try FileManager.default.moveItem(at: location, to: persistedURL)
            lock.lock()
            partRequests[downloadTask.taskIdentifier]?.persistedURL = persistedURL
            lock.unlock()
        } catch {
            lock.lock()
            partRequests[downloadTask.taskIdentifier]?.moveError = error
            lock.unlock()
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        lock.lock()
        let req = partRequests.removeValue(forKey: task.taskIdentifier)
        lock.unlock()

        guard let req = req else { return }

        if let error = error {
            req.continuation.resume(throwing: error)
        } else if let moveError = req.moveError {
            req.continuation.resume(throwing: moveError)
        } else if let url = req.persistedURL {
            // 校验 HTTP 状态码
            if let http = task.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                try? FileManager.default.removeItem(at: url)
                req.continuation.resume(throwing: NSError(
                    domain: "DownloadManager",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
                ))
            } else {
                req.continuation.resume(returning: url)
            }
        } else {
            req.continuation.resume(throwing: URLError(.cannotOpenFile))
        }
    }
}

// MARK: - Download Runner

nonisolated struct DownloadRunner {
    enum Outcome {
        case success
        case cancelled
        case failed(Error)
    }

    let client: Client
    let urlSession: URLSession
    let sessionDelegate: DownloadSessionDelegate
    let task: DownloadTask
    let settings: DownloadSettings.Snapshot

    func run() async -> Outcome {
        let totalSize = task.totalSize
        let targetURL = task.localURL
        let tempURL = targetURL.appendingPathExtension("download")

        // 确保目标目录存在
        do {
            try FileManager.default.createDirectory(
                at: targetURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            return .failed(error)
        }

        // 预签名一次（6 小时内有效，覆盖大多数下载场景）
        let presignResult: PresignResult
        do {
            presignResult = try await client.presign(
                GetObjectRequest(bucket: task.bucketName, key: task.key),
                Date().addingTimeInterval(6 * 3600)
            )
        } catch {
            return .failed(error)
        }

        guard let downloadURL = URL(string: presignResult.url) else {
            return .failed(URLError(.badURL))
        }
        let signedHeaders = presignResult.signedHeaders ?? [:]

        // 计算分片
        let useMultipart = totalSize >= settings.multipartThreshold && totalSize > 0
        let partSize = useMultipart ? settings.partSize : totalSize
        let totalParts: Int
        if totalSize == 0 {
            totalParts = 1
        } else {
            totalParts = Int((totalSize + partSize - 1) / partSize)
        }

        await MainActor.run {
            task.partSize = partSize
            task.totalParts = totalParts
            task.completedParts = 0
        }

        // 空文件
        if totalSize == 0 {
            FileManager.default.createFile(atPath: targetURL.path, contents: nil)
            return .success
        }

        let writer: DownloadFileWriter
        do {
            writer = try DownloadFileWriter(tempURL: tempURL, totalSize: totalSize)
        } catch {
            return .failed(error)
        }

        let counter = DownloadByteCounter()
        let progressTicker = ProgressTicker(task: task, counter: counter)
        await progressTicker.start()

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                var nextPartIndex = 0
                let concurrency = max(1, settings.maxConcurrency)

                while nextPartIndex < totalParts && nextPartIndex < concurrency {
                    let idx = nextPartIndex
                    group.addTask { [urlSession, sessionDelegate, settings] in
                        try await Self.downloadPart(
                            index: idx,
                            totalParts: totalParts,
                            partSize: partSize,
                            totalSize: totalSize,
                            downloadURL: downloadURL,
                            signedHeaders: signedHeaders,
                            urlSession: urlSession,
                            sessionDelegate: sessionDelegate,
                            writer: writer,
                            counter: counter,
                            maxRetry: settings.maxPartRetry
                        )
                    }
                    nextPartIndex += 1
                }

                while try await group.next() != nil {
                    await MainActor.run {
                        task.completedParts = min(task.completedParts + 1, task.totalParts)
                    }
                    if nextPartIndex < totalParts {
                        let idx = nextPartIndex
                        group.addTask { [urlSession, sessionDelegate, settings] in
                            try await Self.downloadPart(
                                index: idx,
                                totalParts: totalParts,
                                partSize: partSize,
                                totalSize: totalSize,
                                downloadURL: downloadURL,
                                signedHeaders: signedHeaders,
                                urlSession: urlSession,
                                sessionDelegate: sessionDelegate,
                                writer: writer,
                                counter: counter,
                                maxRetry: settings.maxPartRetry
                            )
                        }
                        nextPartIndex += 1
                    }
                }
            }
        } catch is CancellationError {
            await progressTicker.stop()
            await writer.cleanup()
            return .cancelled
        } catch {
            await progressTicker.stop()
            await writer.cleanup()
            return .failed(error)
        }

        await progressTicker.stop()
        await writer.close()

        do {
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: targetURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return .failed(error)
        }

        return .success
    }

    private static func downloadPart(
        index: Int,
        totalParts: Int,
        partSize: Int64,
        totalSize: Int64,
        downloadURL: URL,
        signedHeaders: [String: String],
        urlSession: URLSession,
        sessionDelegate: DownloadSessionDelegate,
        writer: DownloadFileWriter,
        counter: DownloadByteCounter,
        maxRetry: Int
    ) async throws {
        let start = Int64(index) * partSize
        let end = min(start + partSize, totalSize) - 1
        let expectedLength = end - start + 1
        let useRange = totalParts > 1

        var attempt = 0
        var lastError: Error?

        while attempt <= maxRetry {
            try Task.checkCancellation()

            var urlRequest = URLRequest(url: downloadURL)
            for (key, value) in signedHeaders {
                urlRequest.addValue(value, forHTTPHeaderField: key)
            }
            if useRange {
                urlRequest.addValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")
            }

            do {
                let partTempURL = try await fetchPart(
                    urlRequest: urlRequest,
                    urlSession: urlSession,
                    sessionDelegate: sessionDelegate,
                    counter: counter
                )
                defer { try? FileManager.default.removeItem(at: partTempURL) }

                try Task.checkCancellation()

                let attributes = try FileManager.default.attributesOfItem(atPath: partTempURL.path)
                let actualSize = (attributes[.size] as? Int64) ?? 0
                if useRange && actualSize != expectedLength {
                    throw NSError(
                        domain: "DownloadManager",
                        code: -11,
                        userInfo: [NSLocalizedDescriptionKey: "Part size mismatch: expected \(expectedLength), got \(actualSize)"]
                    )
                }

                let data = try Data(contentsOf: partTempURL)
                try await writer.write(data, at: UInt64(start))
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                attempt += 1
                if attempt > maxRetry { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        throw lastError ?? NSError(
            domain: "DownloadManager",
            code: -12,
            userInfo: [NSLocalizedDescriptionKey: "Part \(index) failed after retries"]
        )
    }

    private static func fetchPart(
        urlRequest: URLRequest,
        urlSession: URLSession,
        sessionDelegate: DownloadSessionDelegate,
        counter: DownloadByteCounter
    ) async throws -> URL {
        let box = URLTaskBox()

        return try await withTaskCancellationHandler(
            operation: {
                try Task.checkCancellation()
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                    // 不传 completion handler —— 让委托方法生效（didWriteData 进度、didFinishDownloadingTo、didCompleteWithError）
                    let urlTask = urlSession.downloadTask(with: urlRequest)
                    box.task = urlTask
                    sessionDelegate.register(counter: counter, continuation: continuation, for: urlTask)
                    urlTask.resume()
                }
            },
            onCancel: {
                box.task?.cancel()
            }
        )
    }
}

nonisolated final class URLTaskBox: @unchecked Sendable {
    nonisolated(unsafe) var task: URLSessionTask?
}

// MARK: - Progress Ticker

actor ProgressTicker {
    private let task: DownloadTask
    private let counter: DownloadByteCounter
    private var tickTask: Task<Void, Never>?

    init(task: DownloadTask, counter: DownloadByteCounter) {
        self.task = task
        self.counter = counter
    }

    func start() {
        tickTask?.cancel()
        tickTask = Task { [task, counter] in
            while !Task.isCancelled {
                let current = counter.total
                let total = await MainActor.run { task.totalSize }
                await MainActor.run {
                    task.downloadedBytes = current
                    if total > 0 {
                        task.progress = min(1.0, Double(current) / Double(total))
                    }
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }
}
