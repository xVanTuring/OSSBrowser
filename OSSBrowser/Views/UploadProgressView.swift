//
//  UploadProgressView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/10.
//

import SwiftUI

struct UploadProgressWindow: View {
    @ObservedObject private var uploadManager = UploadManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("上传管理")
                    .font(.headline)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("关闭")
            }
            .padding()

            Divider()

            // 上传任务列表
            if uploadManager.uploadTasks.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("没有上传任务")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // 统计信息
                    let stats = uploadManager.getUploadProgress()
                    HStack {
                        Text("总计: \(stats.total) | 完成: \(stats.completed) | 上传中: \(stats.uploading) | 失败: \(stats.failed)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("清除已完成") {
                            uploadManager.clearCompletedTasks()
                        }
                        .font(.caption)
                        .disabled(stats.completed == 0)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    Divider()

                    // 任务列表
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(uploadManager.uploadTasks) { task in
                                UploadTaskRowView(task: task)
                            }
                        }
                    }
                }
            }

            Divider()

            // 底部按钮
            HStack {
                Button("全部暂停") {
                    // TODO: 实现暂停功能
                }
                .disabled(true)

                Spacer()

                Button("关闭") {
                    dismiss()
                }
            }
            .padding()
        }
        .frame(width: 600, height: 400)
    }
}

struct UploadTaskRowView: View {
    @ObservedObject var task: UploadTask
    @ObservedObject private var uploadManager = UploadManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: task.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(.blue)
                .frame(width: 20, height: 20)

            // 文件信息
            VStack(alignment: .leading, spacing: 4) {
                Text(task.fileName)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Text(task.remotePath)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(ByteCountFormatter.string(fromByteCount: task.fileSize, countStyle: .file))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 状态和进度
            VStack(alignment: .trailing, spacing: 4) {
                switch task.status {
                case .pending:
                    Text("等待中")
                        .font(.caption)
                        .foregroundColor(.orange)

                case .uploading(let progress):
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 100)

                case .completed:
                    Text("已完成")
                        .font(.caption)
                        .foregroundColor(.green)

                case .failed:
                    Text("失败")
                        .font(.caption)
                        .foregroundColor(.red)
                    Button("重试") {
                        uploadManager.retryFailedTask(task)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            backgroundColorForTask(task)
        )
    }

    private func backgroundColorForTask(_ task: UploadTask) -> Color {
        if case .failed = task.status {
            return Color.red.opacity(0.1)
        }
        return Color.clear
    }
}

#Preview {
    UploadProgressWindow()
}