//
//  VideoPreview.swift
//  OSSBrowser
//
//  视频预览：通过预签名 URL 使用 AVKit 流式播放。
//  对 AVFoundation 无法播放的容器/编码（如 mkv、webm）给出下载降级提示。
//

import SwiftUI
import AVKit

struct VideoPreview: View {
    let file: OSSFile
    let bucketName: String
    let config: OSSConfiguration

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var unsupported = false

    var body: some View {
        ZStack {
            Color.black
            if let player = player {
                // 用 AppKit 原生 AVPlayerView，避开 SwiftUI VideoPlayer 的泛型元数据崩溃
                AVPlayerViewRepresentable(player: player)
            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.3)
                    Text("正在准备播放…")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            } else if unsupported {
                PreviewMessageView(
                    systemImage: "film.stack",
                    title: "此视频格式暂不支持在线播放",
                    subtitle: "macOS 播放器无法解码该格式（如 mkv / webm 等），可下载后用其他播放器打开。",
                    tint: .orange
                )
            } else if let loadError = loadError {
                PreviewMessageView(
                    systemImage: "exclamationmark.triangle",
                    title: "加载失败",
                    subtitle: loadError.localizedDescription,
                    tint: .orange
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await load() }
        .onDisappear { player?.pause() }
    }

    private func load() async {
        do {
            let url = try await OSSPresigner.presignedURL(
                bucket: bucketName, key: file.key, config: config)

            let asset = AVURLAsset(url: url)
            let playable = try await asset.load(.isPlayable)
            guard playable else {
                await MainActor.run {
                    unsupported = true
                    isLoading = false
                }
                return
            }

            let item = AVPlayerItem(asset: asset)
            await MainActor.run {
                let avPlayer = AVPlayer(playerItem: item)
                player = avPlayer
                isLoading = false
                avPlayer.play()
            }
        } catch {
            await MainActor.run {
                loadError = error
                isLoading = false
            }
        }
    }
}

/// AppKit AVPlayerView 封装（替代 SwiftUI VideoPlayer，避免其泛型元数据崩溃）
private struct AVPlayerViewRepresentable: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline
        view.videoGravity = .resizeAspect
        view.allowsPictureInPicturePlayback = true
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
