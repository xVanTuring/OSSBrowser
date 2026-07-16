//
//  DownloadProgressWindow.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/10.
//

import SwiftUI
import AppKit

struct DownloadProgressWindow: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) private var dismiss

    private var stats: (total: Int, completed: Int, active: Int, failed: Int) {
        var completed = 0, active = 0, failed = 0
        for t in downloadManager.downloadTasks {
            switch t.status {
            case .completed: completed += 1
            case .downloading, .pending: active += 1
            case .failed: failed += 1
            case .cancelled: break
            }
        }
        return (downloadManager.downloadTasks.count, completed, active, failed)
    }

    private var hasFinishedTasks: Bool {
        downloadManager.downloadTasks.contains {
            $0.status == .completed || $0.status == .failed || $0.status == .cancelled
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("下载任务")
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

            if downloadManager.downloadTasks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("暂无下载任务")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 统计条
                HStack {
                    Text("总计: \(stats.total) | 完成: \(stats.completed) | 下载中: \(stats.active) | 失败: \(stats.failed)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("清除已结束") {
                        downloadManager.removeCompletedTasks()
                    }
                    .font(.caption)
                    .disabled(!hasFinishedTasks)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(downloadManager.downloadTasks) { task in
                            DownloadTaskRow(task: task)
                        }
                    }
                }
            }
        }
        .frame(width: 620, height: 420)
    }
}

// 下载任务行
struct DownloadTaskRow: View {
    @ObservedObject var task: DownloadTask
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.fileName)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(task.fileName)

                    HStack(spacing: 12) {
                        Text(ByteCountFormatter.string(fromByteCount: task.totalSize, countStyle: .file))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(statusColor)
                        if task.status == .downloading {
                            Text(task.downloadSpeed)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let remainingTime = task.remainingTime {
                                Text(remainingTime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // 失败原因
                    if task.status == .failed, let error = task.error {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                            .help(error.localizedDescription)
                    }
                }

                Spacer()

                actionButtons
            }

            // 进度条（仅下载中）
            if task.status == .downloading {
                HStack(spacing: 8) {
                    ProgressView(value: task.progress)
                        .progressViewStyle(.linear)
                    Text("\(task.progressPercentage)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.leading, 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(rowBackground)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if task.status == .failed { return Color.red.opacity(0.08) }
        return isHovered ? Color.primary.opacity(0.04) : Color.clear
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch task.status {
        case .downloading, .pending:
            Button("取消") { downloadManager.cancelDownload(task.id) }
                .controlSize(.small)
                .help("取消下载")
        case .completed:
            HStack(spacing: 6) {
                Button {
                    NSWorkspace.shared.open(task.localURL)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .controlSize(.small)
                .help("打开文件")

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([task.localURL])
                } label: {
                    Image(systemName: "folder")
                }
                .controlSize(.small)
                .help("在访达中显示")

                removeButton
            }
        case .failed:
            HStack(spacing: 6) {
                Button("重试") { downloadManager.retryFailedTask(task) }
                    .controlSize(.small)
                    .help("重新下载")
                removeButton
            }
        case .cancelled:
            removeButton
        }
    }

    private var removeButton: some View {
        Button {
            downloadManager.removeTask(task)
        } label: {
            Image(systemName: "xmark")
        }
        .controlSize(.small)
        .help("从列表移除")
        .opacity(isHovered ? 1 : 0)
    }

    private var statusIcon: String {
        switch task.status {
        case .pending: return "clock"
        case .downloading: return "arrow.down.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle"
        }
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
        case .pending: return .orange
        case .downloading: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

#Preview {
    DownloadProgressWindow()
}
