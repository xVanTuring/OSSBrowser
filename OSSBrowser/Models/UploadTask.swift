//
//  UploadTask.swift
//  OSSBrowser
//

import Foundation
import Combine

enum UploadTaskStatus {
    case pending
    case uploading
    case completed
    case failed
    case cancelled
}

class UploadTask: ObservableObject, Identifiable {
    let id = UUID()
    let fileName: String
    let localPath: String
    let remotePath: String
    let fileSize: Int64
    let isDirectory: Bool

    @Published var status: UploadTaskStatus = .pending
    @Published var uploadedBytes: Int64 = 0
    @Published var progress: Double = 0.0
    @Published var error: Error?
    @Published var startTime: Date?
    @Published var endTime: Date?

    // 分片上传相关（Manager 启动任务时写入）
    @Published var partSize: Int64 = 0
    @Published var completedParts: Int = 0
    @Published var totalParts: Int = 1

    /// 瞬时速度（字节/秒），由 recordProgress 基于相邻采样计算
    @Published var currentSpeed: Double = 0
    private var speedLastBytes: Int64 = 0
    private var speedLastTime: Date?

    init(fileName: String, localPath: String, remotePath: String, fileSize: Int64, isDirectory: Bool = false) {
        self.fileName = fileName
        self.localPath = localPath
        self.remotePath = remotePath
        self.fileSize = fileSize
        self.isDirectory = isDirectory
    }

    var progressPercentage: Int {
        Int(progress * 100)
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
        uploadedBytes = bytes
    }

    var uploadSpeed: String {
        guard currentSpeed > 0 else { return "0 B/s" }
        return ByteCountFormatter.string(fromByteCount: Int64(currentSpeed), countStyle: .file) + "/s"
    }

    var remainingTime: String? {
        guard currentSpeed > 0, fileSize > 0, uploadedBytes < fileSize else { return nil }
        let remainingBytes = Double(fileSize - uploadedBytes)
        let remainingSeconds = remainingBytes / currentSpeed
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(remainingSeconds))
    }
}
