//
//  FileTable.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/14.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileTable: View {
    let files: [OSSFile]
    @Binding var selectedFiles: Set<String>
    let onFileDoubleClick: (OSSFile) -> Void
    let dropHandler: FileDropHandler
    let keyboardHandler: FileKeyboardHandler
    var onLoadMore: (() -> Void)? = nil

    @State private var sortedFiles: [OSSFile] = []
    @State private var sortOrder: [KeyPathComparator<OSSFile>] = [.init(\.name)]
    @State private var dropAreaActive = false

    // 用于 Table 的选择状态
    private var selectedFileIds: Binding<Set<String>> {
        Binding {
            selectedFiles
        } set: { newValue in
            selectedFiles = newValue
        }
    }

    var body: some View {
        Table(sortedFiles, selection: selectedFileIds, sortOrder: $sortOrder) {
            // 名称列
            TableColumn("名称", value: \.name) { file in
                HStack(spacing: 8) {
                    Image(systemName: file.iconName)
                        .foregroundColor(file.category.tint)
                        .frame(width: 16, height: 16)
                    Text(file.name)
                        .font(.body)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onAppear {
                    if file.id == sortedFiles.last?.id {
                        onLoadMore?()
                    }
                }
            }
            .width(min: 300, ideal: 500, max: 800)

            // 修改日期列
            TableColumn("修改日期", value: \.lastModified) { file in
                Text(file.lastModified, format: .dateTime)
                    .foregroundColor(.secondary)
            }
            .width(min: 150, ideal: 180, max: 250)

            // 大小列
            TableColumn("大小", value: \.size) { file in
                Text(file.fileSizeString)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 100, max: 150)
        }
        .onChange(of: sortOrder) { _, newOrder in
            withAnimation(.easeInOut(duration: 0.2)) {
                sortedFiles = sortedFoldersFirst(files, using: newOrder)
            }
        }
        .onChange(of: files) { _, newFiles in
            withAnimation(.easeInOut(duration: 0.2)) {
                sortedFiles = sortedFoldersFirst(newFiles, using: sortOrder)
            }
        }
        .onAppear {
            sortedFiles = sortedFoldersFirst(files, using: sortOrder)
        }
        .tableStyle(.inset)
        .alternatingRowBackgrounds()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $dropAreaActive) { providers in
            dropHandler.handleDrop(providers: providers)
        }
        .background(dropAreaActive ? Color.accentColor.opacity(0.1) : Color.clear)
        .onKeyPress { key in
            keyboardHandler.handleKeyPress(key)
        }
    }

    /// 排序：始终把文件夹分组置顶，组内再按当前列排序规则
    private func sortedFoldersFirst(
        _ list: [OSSFile],
        using order: [KeyPathComparator<OSSFile>]
    ) -> [OSSFile] {
        list.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            for comparator in order {
                let result = comparator.compare(lhs, rhs)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
            }
            return false
        }
    }
}