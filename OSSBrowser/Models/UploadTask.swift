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

    var uploadSpeed: String {
        guard let startTime = startTime else { return "0 B/s" }
        let elapsedTime = Date().timeIntervalSince(startTime)
        guard elapsedTime > 0 else { return "0 B/s" }
        let speed = Double(uploadedBytes) / elapsedTime
        return ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s"
    }

    var remainingTime: String? {
        guard let startTime = startTime, uploadedBytes > 0, fileSize > 0 else { return nil }
        let elapsedTime = Date().timeIntervalSince(startTime)
        let speed = Double(uploadedBytes) / elapsedTime
        if speed == 0 { return nil }
        let remainingBytes = fileSize - uploadedBytes
        let remainingSeconds = Double(remainingBytes) / speed
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(remainingSeconds))
    }
}
