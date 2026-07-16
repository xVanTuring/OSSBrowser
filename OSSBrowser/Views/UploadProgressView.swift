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

    private var hasFinishedTasks: Bool {
        uploadManager.uploadTasks.contains {
            $0.status == .completed || $0.status == .failed || $0.status == .cancelled
        }
    }

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
                .buttonStyle(.plain)
                .help("关闭")
            }
            .padding()

            Divider()

            // 上传任务列表
            if uploadManager.uploadTasks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("没有上传任务")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 统计信息
                let stats = uploadManager.getUploadProgress()
                HStack {
                    Text("总计: \(stats.total) | 完成: \(stats.completed) | 上传中: \(stats.uploading) | 失败: \(stats.failed)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("清除已结束") {
                        uploadManager.clearCompletedTasks()
                    }
                    .font(.caption)
                    .disabled(!hasFinishedTasks)
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
        .frame(width: 620, height: 420)
    }
}

struct UploadTaskRowView: View {
    @ObservedObject var task: UploadTask
    @ObservedObject private var uploadManager = UploadManager.shared
    @State private var isHovered = false

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
                    .truncationMode(.middle)
                    .help(task.fileName)

                Text(task.remotePath)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(task.remotePath)

                Text(ByteCountFormatter.string(fromByteCount: task.fileSize, countStyle: .file))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                // 失败原因
                if task.status == .failed, let error = task.error {
                    Text(error.localizedDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(2)
                        .help(error.localizedDescription)
                }
            }

            Spacer()

            // 状态和进度
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(rowBackground)
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if task.status == .failed { return Color.red.opacity(0.1) }
        return isHovered ? Color.primary.opacity(0.04) : Color.clear
    }

    @ViewBuilder
    private var trailing: some View {
        switch task.status {
        case .pending:
            HStack(spacing: 6) {
                Text("等待中")
                    .font(.caption)
                    .foregroundColor(.orange)
                removeButton
            }

        case .uploading:
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(task.progressPercentage)%")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 120)
                HStack(spacing: 6) {
                    Text(task.uploadSpeed)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    if let rt = task.remainingTime {
                        Text(rt)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

        case .completed:
            HStack(spacing: 6) {
                Label("已完成", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundColor(.green)
                removeButton
            }

        case .failed:
            HStack(spacing: 6) {
                Text("失败")
                    .font(.caption)
                    .foregroundColor(.red)
                Button("重试") {
                    uploadManager.retryFailedTask(task)
                }
                .controlSize(.small)
                .help("重新上传")
                removeButton
            }

        case .cancelled:
            HStack(spacing: 6) {
                Text("已取消")
                    .font(.caption)
                    .foregroundColor(.gray)
                removeButton
            }
        }
    }

    private var removeButton: some View {
        Button {
            uploadManager.removeTask(task)
        } label: {
            Image(systemName: "xmark")
        }
        .controlSize(.small)
        .help("从列表移除")
        .opacity(isHovered ? 1 : 0)
    }

    private var statusText: String {
        if task.totalParts > 1 {
            return "上传中 (\(task.completedParts)/\(task.totalParts))"
        }
        return "上传中"
    }
}

#Preview {
    UploadProgressWindow()
}
