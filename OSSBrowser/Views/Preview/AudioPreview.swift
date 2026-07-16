//
//  AudioPreview.swift
//  OSSBrowser
//
//  音频预览：通过预签名 URL 使用 AVPlayer 播放，提供紧凑的播放/进度控制。
//

import SwiftUI
import AVFoundation

struct AudioPreview: View {
    let file: OSSFile
    let bucketName: String
    let config: OSSConfiguration

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.3)
                    Text("正在加载音频…")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError = loadError {
                PreviewMessageView(
                    systemImage: "exclamationmark.triangle",
                    title: "加载失败",
                    subtitle: loadError.localizedDescription,
                    tint: .orange
                )
            } else {
                playerBody
            }
        }
        .task { await load() }
        .onDisappear { teardown() }
    }

    private var playerBody: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text(file.name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 6) {
                Slider(
                    value: Binding(
                        get: { currentTime },
                        set: { seek(to: $0) }
                    ),
                    in: 0...max(duration, 0.1)
                )

                HStack {
                    Text(timeString(currentTime))
                    Spacer()
                    Text(timeString(duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: 360)

            Button(action: togglePlay) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Playback

    private func load() async {
        do {
            let url = try await OSSPresigner.presignedURL(
                bucket: bucketName, key: file.key, config: config)
            let asset = AVURLAsset(url: url)
            let loadedDuration = try await asset.load(.duration)
            let item = AVPlayerItem(asset: asset)

            await MainActor.run {
                let avPlayer = AVPlayer(playerItem: item)
                self.duration = loadedDuration.seconds.isFinite ? loadedDuration.seconds : 0
                self.player = avPlayer
                self.isLoading = false
                addTimeObserver(to: avPlayer)
                avPlayer.play()
                self.isPlaying = true
            }
        } catch {
            await MainActor.run {
                self.loadError = error
                self.isLoading = false
            }
        }
    }

    private func addTimeObserver(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.3, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval, queue: .main
        ) { time in
            let seconds = time.seconds
            if seconds.isFinite {
                self.currentTime = seconds
            }
            // 播放结束后同步按钮状态
            if let item = player.currentItem,
               item.duration.seconds.isFinite,
               seconds >= item.duration.seconds - 0.25 {
                self.isPlaying = false
            }
        }
    }

    private func togglePlay() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            // 播放结束后再次点击从头播放
            if duration > 0, currentTime >= duration - 0.25 {
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
    }

    private func seek(to seconds: Double) {
        currentTime = seconds
        player?.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func teardown() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player = nil
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
