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

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var downloadTasks: [DownloadTask] = []
    private var client: Client?
    private var activeDownloads: Set<UUID> = []
    private let maxConcurrentDownloads = 5

    private init() {
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
                if task.totalSize > 100 * 1024 * 1024 { // 100MB
                    try await downloadWithParts(client: client, task: task)
                } else {
                    try await downloadSingle(client: client, task: task)
                }

                task.status = .completed
                task.endTime = Date()
                task.progress = 1.0
                task.downloadedBytes = task.totalSize

                await MainActor.run {
                    sendNotification(title: "下载完成", body: "\(task.fileName) 下载完成")
                    activeDownloads.remove(task.id)
                    processQueue()
                }
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

    private func downloadSingle(client: Client, task: DownloadTask) async throws {
        // 确保目标目录存在
        let parentDir = task.localURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // 使用 client.getObjectToFile 直接下载到文件
        let request = GetObjectRequest(bucket: task.bucketName, key: task.key)
        try await client.getObjectToFile(request, task.localURL)

        await MainActor.run {
            task.downloadedBytes = task.totalSize
            task.progress = 1.0
        }
    }

    private func downloadWithParts(client: Client, task: DownloadTask) async throws {
        // 确保目标目录存在
        let parentDir = task.localURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // 使用 client.getObjectToFile 直接下载到文件（SDK会自动处理大文件）
        let request = GetObjectRequest(bucket: task.bucketName, key: task.key)
        try await client.getObjectToFile(request, task.localURL)

        // 更新进度
        await MainActor.run {
            task.downloadedBytes = task.totalSize
            task.progress = 1.0
            task.completedParts = task.totalParts
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