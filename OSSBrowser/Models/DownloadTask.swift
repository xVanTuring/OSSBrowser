//
//  DownloadTask.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/10.
//

import Foundation
import Combine

enum DownloadTaskStatus {
    case pending      // 等待下载
    case downloading  // 下载中
    case completed    // 下载完成
    case failed       // 下载失败
    case cancelled    // 已取消
}

class DownloadTask: ObservableObject, Identifiable {
    let id = UUID()
    let fileName: String
    let key: String
    let bucketName: String
    let totalSize: Int64
    let localURL: URL

    @Published var status: DownloadTaskStatus = .pending
    @Published var downloadedBytes: Int64 = 0
    @Published var progress: Double = 0.0
    @Published var error: Error?
    @Published var startTime: Date?
    @Published var endTime: Date?

    // 分片下载相关（由 DownloadManager 在开始下载时写入）
    @Published var partSize: Int64 = 0
    @Published var completedParts: Int = 0
    @Published var totalParts: Int = 1

    init(fileName: String, key: String, bucketName: String, totalSize: Int64, localURL: URL) {
        self.fileName = fileName
        self.key = key
        self.bucketName = bucketName
        self.totalSize = totalSize
        self.localURL = localURL
    }

    var progressPercentage: Int {
        return Int(progress * 100)
    }

    var downloadSpeed: String {
        guard let startTime = startTime else { return "0 B/s" }

        let elapsedTime = Date().timeIntervalSince(startTime)
        guard elapsedTime > 0 else { return "0 B/s" }

        let speed = Double(downloadedBytes) / elapsedTime
        return ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s"
    }

    var remainingTime: String? {
        guard let startTime = startTime, downloadedBytes > 0, totalSize > 0 else { return nil }

        let elapsedTime = Date().timeIntervalSince(startTime)
        let speed = Double(downloadedBytes) / elapsedTime

        if speed == 0 { return nil }

        let remainingBytes = totalSize - downloadedBytes
        let remainingSeconds = Double(remainingBytes) / speed

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated

        return formatter.string(from: TimeInterval(remainingSeconds))
    }
}
