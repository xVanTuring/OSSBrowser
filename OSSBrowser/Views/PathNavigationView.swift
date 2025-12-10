//
//  PathNavigationView.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/10.
//

import SwiftUI

struct PathNavigationView: View {
    let bucketName: String
    let currentPath: String
    let onPathClick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 8) {
                // 根路径 - 桶名
                Button(action: {
                    onPathClick("")
                }) {
                    Text(bucketName)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isHovering in
                    if isHovering {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }

                // 分隔符和路径组件
                if !currentPath.isEmpty {
                    ForEach(pathComponents, id: \.self) { component in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Button(action: {
                            onPathClick(pathToComponent[component] ?? "")
                        }) {
                            Text(component)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isLastPathComponent(component) ?
                                              Color(NSColor.selectedControlColor) :
                                              Color(NSColor.controlBackgroundColor))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { isHovering in
                            if isHovering {
                                NSCursor.pointingHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(height: 32)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
        .border(Color(NSColor.separatorColor), width: 0.5)
    }

    // 将路径分割成组件
    private var pathComponents: [String] {
        return currentPath.components(separatedBy: "/")
            .filter { !$0.isEmpty }
    }

    // 创建组件到对应路径的映射
    private var pathToComponent: [String: String] {
        var result: [String: String] = [:]
        var currentPath = ""

        for component in pathComponents {
            let newPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"
            result[component] = newPath
            currentPath = newPath
        }

        return result
    }

    // 判断是否是最后一个路径组件
    private func isLastPathComponent(_ component: String) -> Bool {
        return pathComponents.last == component
    }
}

#Preview {
    VStack(spacing: 0) {
        Spacer()
        PathNavigationView(
            bucketName: "my-bucket",
            currentPath: "folder1/folder2/folder3",
            onPathClick: { path in
                print("Clicked path: \(path)")
            }
        )
    }
    .frame(width: 600, height: 200)
}
