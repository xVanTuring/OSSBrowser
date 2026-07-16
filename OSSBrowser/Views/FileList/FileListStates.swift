//
//  FileListStates.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/14.
//

import SwiftUI

struct FileListStates {

    struct LoadingView: View {
        var body: some View {
            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Text("加载中…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    struct EmptyFolderView: View {
        var onUpload: (() -> Void)? = nil

        var body: some View {
            VStack {
                Spacer()
                if let onUpload {
                    ContentUnavailableView {
                        Label("空文件夹", systemImage: "folder")
                    } description: {
                        Text("这个文件夹还没有文件")
                    } actions: {
                        Button {
                            onUpload()
                        } label: {
                            Label("上传文件", systemImage: "arrow.up.doc")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ContentUnavailableView(
                        "空文件夹",
                        systemImage: "folder",
                        description: Text("这个文件夹还没有文件")
                    )
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 搜索无命中（区别于目录本身为空）
    struct SearchEmptyView: View {
        let query: String
        var onClear: (() -> Void)? = nil

        var body: some View {
            VStack {
                Spacer()
                ContentUnavailableView {
                    Label("未找到匹配项", systemImage: "magnifyingglass")
                } description: {
                    Text("没有找到以 “\(query)” 开头的文件")
                } actions: {
                    if let onClear {
                        Button("清除搜索") { onClear() }
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 列表加载失败态（带重试）
    struct ErrorView: View {
        let message: String
        let onRetry: () -> Void

        var body: some View {
            VStack {
                Spacer()
                ContentUnavailableView {
                    Label("加载失败", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button {
                        onRetry()
                    } label: {
                        Label("重试", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
