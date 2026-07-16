//
//  ZoomableImageView.swift
//  OSSBrowser
//
//  图片查看器：支持缩放（MagnifyGesture / 工具条）、拖拽平移、旋转 90°、
//  「适应窗口 / 100%」切换，并为可能包含透明区域的图片绘制棋盘格背景。
//

import SwiftUI

struct ZoomableImageView: View {
    let image: Image
    /// 图片像素尺寸，用于计算「100% 实际大小」与缩放百分比
    let pixelSize: CGSize
    /// 是否绘制透明棋盘格背景（PNG / 图标等）
    var showsCheckerboard: Bool = false

    // scale = 1 表示「适应窗口」，其余为相对适应比例的缩放
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @State private var didInit = false

    // 手势进行中的临时状态（结束后并入上面的持久状态）
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureOffset: CGSize = .zero

    private let minScale: CGFloat = 0.1
    private let maxScale: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let fitScale = fitScale(container: geo.size)
            let scale100 = fitScale > 0 ? 1 / fitScale : 1
            let percent = scale100 > 0 ? Int((scale / scale100 * 100).rounded()) : 100

            ZStack {
                if showsCheckerboard {
                    CheckerboardBackground()
                }
                imageLayer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .simultaneousGesture(magnifyGesture)
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    // 双击在「适应窗口」与「实际大小」之间切换
                    scale = abs(scale - 1) < 0.01 ? scale100 : 1
                    offset = .zero
                }
            }
            .overlay(alignment: .top) {
                toolbar(scale100: scale100, percent: percent)
                    .padding(.top, 12)
            }
            .onAppear {
                guard !didInit, geo.size.width > 0, geo.size.height > 0 else { return }
                didInit = true
                // 小图默认按实际像素显示，避免被放大变糊（与旧版行为一致）
                if fitScale > 1 { scale = 1 / fitScale }
            }
        }
    }

    private var imageLayer: some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(scale * gestureScale)
            .rotationEffect(rotation)
            .offset(
                x: offset.width + gestureOffset.width,
                y: offset.height + gestureOffset.height
            )
    }

    // MARK: - 悬浮工具条

    private func toolbar(scale100: CGFloat, percent: Int) -> some View {
        HStack(spacing: 6) {
            iconButton("minus.magnifyingglass", "缩小") {
                withAnimation(.easeInOut(duration: 0.15)) { scale = clamp(scale * 0.8) }
            }
            Text("\(percent)%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44)
            iconButton("plus.magnifyingglass", "放大") {
                withAnimation(.easeInOut(duration: 0.15)) { scale = clamp(scale * 1.25) }
            }

            Divider().frame(height: 16)

            iconButton("rotate.right", "旋转 90°") {
                withAnimation(.easeInOut(duration: 0.2)) { rotation += .degrees(90) }
            }

            Divider().frame(height: 16)

            iconButton("arrow.up.left.and.arrow.down.right", "适应窗口") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    scale = 1
                    offset = .zero
                }
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    scale = scale100
                    offset = .zero
                }
            } label: {
                Text("1:1")
                    .font(.caption.bold())
                    .frame(width: 26, height: 22)
            }
            .buttonStyle(.plain)
            .help("实际大小 100%")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
        .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
    }

    private func iconButton(
        _ systemName: String, _ help: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - 手势

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($gestureScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                scale = clamp(scale * value.magnification)
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($gestureOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
            }
    }

    // MARK: - 辅助

    private func fitScale(container: CGSize) -> CGFloat {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return 1 }
        return min(container.width / pixelSize.width, container.height / pixelSize.height)
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, minScale), maxScale)
    }
}

/// 透明图片的标准棋盘格背景
private struct CheckerboardBackground: View {
    var square: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / square))
            let rows = Int(ceil(size.height / square))
            let light = Color(white: 0.86)
            let dark = Color(white: 0.72)
            for row in 0..<max(rows, 1) {
                for col in 0..<max(cols, 1) {
                    let rect = CGRect(
                        x: CGFloat(col) * square,
                        y: CGFloat(row) * square,
                        width: square, height: square)
                    let color = (row + col).isMultiple(of: 2) ? light : dark
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
