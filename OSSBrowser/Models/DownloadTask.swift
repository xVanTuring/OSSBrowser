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

    /// 瞬时速度（字节/秒），由 recordProgress 基于相邻采样计算
    @Published var currentSpeed: Double = 0
    private var speedLastBytes: Int64 = 0
    private var speedLastTime: Date?

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

    /// 记录一次进度采样，更新累计字节与瞬时速度（带指数平滑）
    func recordProgress(_ bytes: Int64) {
        let now = Date()
        if let last = speedLastTime {
            let dt = now.timeIntervalSince(last)
            if dt >= 0.15 {
                let delta = Double(max(0, bytes - speedLastBytes))
                let inst = delta / dt
                currentSpeed = currentSpeed == 0 ? inst : currentSpeed * 0.5 + inst * 0.5
                speedLastBytes = bytes
                speedLastTime = now
            }
        } else {
            speedLastTime = now
            speedLastBytes = bytes
        }
        downloadedBytes = bytes
    }

    var downloadSpeed: String {
        guard currentSpeed > 0 else { return "0 B/s" }
        return ByteCountFormatter.string(fromByteCount: Int64(currentSpeed), countStyle: .file) + "/s"
    }

    var remainingTime: String? {
        guard currentSpeed > 0, totalSize > 0, downloadedBytes < totalSize else { return nil }
        let remainingBytes = Double(totalSize - downloadedBytes)
        let remainingSeconds = remainingBytes / currentSpeed
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(remainingSeconds))
    }
}
