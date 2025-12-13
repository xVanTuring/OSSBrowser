//
//  DownloadManager.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/10.
//

import Foundation
import AlibabaCloudOSS
import AlibabaCloudOSSExtension
import UserNotifications
import Combine

class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var downloadTasks: [DownloadTask] = []
    private var client: Client?
    private var activeDownloads: Set<UUID> = []
    private let maxConcurrentDownloads = 5
    private var urlSession: URLSession?
    private var downloadSessions: [UUID: URLSessionDownloadTask] = [:]

    private override init() {
        super.init()
        requestNotificationPermission()
        setupURLSession()
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
        // 创建文件夹结构
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let folderURL = downloadsURL.appendingPathComponent(folder.name)

        // 创建本地文件夹
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            print("Failed to create directory: \(error)")
            return
        }

        // 递归下载所有文件
        let folderFiles = files.filter { $0.key.hasPrefix(folder.key) && !$0.isDirectory }
        for file in folderFiles {
            let relativePath = String(file.key.dropFirst(folder.key.count))
            let fileURL = folderURL.appendingPathComponent(relativePath)

            // 确保父目录存在
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

        // 取消 URLSessionDownloadTask
        if let downloadTask = downloadSessions[taskId] {
            downloadTask.cancel()
            downloadSessions.removeValue(forKey: taskId)
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

    // MARK: - Private Methods

    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    private func processQueue() {
        // 找到等待中的任务
        let pendingTasks = downloadTasks.filter { $0.status == .pending }
        let availableSlots = maxConcurrentDownloads - activeDownloads.count

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

        Task {
            do {
                // 生成预签名 URL
                let presignResult = try await client.presign(
                    GetObjectRequest(
                        bucket: task.bucketName,
                        key: task.key
                    ),
                    Date().addingTimeInterval(3600) // 1小时有效期
                )

                guard let url = URL(string: presignResult.url) else {
                    throw URLError(.badURL)
                }

                // 使用 URLSession 下载
                await downloadWithURLSession(task: task, url: url, signedHeaders: presignResult.signedHeaders)

            } catch {
                task.error = error
                task.status = .failed
                task.endTime = Date()

                await MainActor.run {
                    sendNotification(title: "下载失败", body: "\(task.fileName) 下载失败: \(error.localizedDescription)")
                    activeDownloads.remove(task.id)
                    processQueue()
                }
            }
        }
    }

    private func downloadWithURLSession(task: DownloadTask, url: URL, signedHeaders: [String: String]?) async {
        return await withCheckedContinuation { continuation in
            guard let urlSession = urlSession else {
                continuation.resume()
                return
            }

            // 确保目标目录存在
            let parentDir = task.localURL.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            } catch {
                Task { @MainActor in
                    task.error = error
                    task.status = .failed
                    task.endTime = Date()
                    self.sendNotification(title: "下载失败", body: "\(task.fileName) 下载失败: \(error.localizedDescription)")
                    self.activeDownloads.remove(task.id)
                    self.processQueue()
                }
                continuation.resume()
                return
            }

            // 创建 URLRequest 并添加签名头部
            var urlRequest = URLRequest(url: url)
            for (key, value) in signedHeaders ?? [:] {
                urlRequest.addValue(value, forHTTPHeaderField: key)
            }

            // 创建下载任务
            let downloadTask = urlSession.downloadTask(with: urlRequest) { [weak self] tempURL, response, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                Task { @MainActor in
                    // 清理会话记录
                    self.downloadSessions.removeValue(forKey: task.id)

                    if let error = error {
                        // 检查是否是用户取消
                        if (error as NSError).code == NSURLErrorCancelled {
                            task.status = .cancelled
                        } else {
                            task.error = error
                            task.status = .failed
                            task.endTime = Date()
                            self.sendNotification(title: "下载失败", body: "\(task.fileName) 下载失败: \(error.localizedDescription)")
                        }
                    } else if let tempURL = tempURL {
                        do {
                            // 移动临时文件到目标位置
                            if FileManager.default.fileExists(atPath: task.localURL.path) {
                                try FileManager.default.removeItem(at: task.localURL)
                            }
                            try FileManager.default.moveItem(at: tempURL, to: task.localURL)

                            task.status = .completed
                            task.endTime = Date()
                            task.progress = 1.0
                            task.downloadedBytes = task.totalSize
                            self.sendNotification(title: "下载完成", body: "\(task.fileName) 下载完成")
                        } catch {
                            task.error = error
                            task.status = .failed
                            task.endTime = Date()
                            self.sendNotification(title: "下载失败", body: "\(task.fileName) 保存失败: \(error.localizedDescription)")
                        }
                    }

                    self.activeDownloads.remove(task.id)
                    self.processQueue()
                    continuation.resume()
                }
            }

            // URLSessionDownloadTask 会自动监控进度

            // 开始下载
            downloadSessions[task.id] = downloadTask
            downloadTask.resume()
        }
    }

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

// MARK: - URLSessionDownloadDelegate
extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 这个方法的实际处理在 downloadTask 的 completionHandler 中
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // 错误处理也在 downloadTask 的 completionHandler 中
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // 更新下载进度
        Task { @MainActor in
            // 找到对应的任务并更新进度
            if let downloadTaskRecord = downloadTasks.first(where: { task in
                downloadSessions[task.id] == downloadTask
            }) {
                downloadTaskRecord.downloadedBytes = totalBytesWritten
                if totalBytesExpectedToWrite > 0 {
                    downloadTaskRecord.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                }

                // 下载速度由 downloadTaskRecord 的 downloadSpeed 计算属性自动计算

                // 更新分片进度（估算）
                if downloadTaskRecord.totalParts > 0 {
                    downloadTaskRecord.completedParts = min(Int(Double(totalBytesWritten) / Double(downloadTaskRecord.partSize)) + 1, downloadTaskRecord.totalParts)
                }
            }
        }
    }
}
