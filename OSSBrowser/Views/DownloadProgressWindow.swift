//
//  DownloadProgressWindow.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/10.
//

import SwiftUI

struct DownloadProgressWindow: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("下载任务")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 下载列表
            if downloadManager.downloadTasks.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("暂无下载任务")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(downloadManager.downloadTasks) { task in
                            DownloadTaskRow(task: task)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Divider()

            // 底部操作栏
            HStack {
                if !downloadManager.downloadTasks.isEmpty {
                    Button("清理已完成") {
                        downloadManager.removeCompletedTasks()
                    }
                    .disabled(downloadManager.downloadTasks.allSatisfy {
                        $0.status == .pending || $0.status == .downloading
                    })
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 400)
    }
}

// 下载任务行
struct DownloadTaskRow: View {
    @ObservedObject var task: DownloadTask
    @ObservedObject var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                // 文件信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.fileName)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        // 文件大小
                        Text(ByteCountFormatter.string(fromByteCount: task.totalSize, countStyle: .file))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // 状态
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(statusColor)

                        // 下载速度（仅下载中显示）
                        if task.status == .downloading {
                            Text(task.downloadSpeed)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // 剩余时间
                            if let remainingTime = task.remainingTime {
                                Text(remainingTime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                // 取消按钮
                if task.status == .downloading || task.status == .pending {
                    Button("取消") {
                        downloadManager.cancelDownload(task.id)
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.small)
                }
            }

            // 进度条
            if task.status == .downloading || task.status == .completed {
                HStack(spacing: 8) {
                    ProgressView(value: task.progress)
                        .progressViewStyle(LinearProgressViewStyle())

                    Text("\(task.progressPercentage)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }

    private var statusText: String {
        switch task.status {
        case .pending:
            return "等待中"
        case .downloading:
            if task.totalParts > 1 {
                return "下载中 (\(task.completedParts)/\(task.totalParts))"
            }
            return "下载中"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        case .cancelled:
            return "已取消"
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .pending:
            return .orange
        case .downloading:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }
}

#Preview {
    DownloadProgressWindow()
}