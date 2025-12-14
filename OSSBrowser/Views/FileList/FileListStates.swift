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
            VStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    struct EmptyFolderView: View {
        var body: some View {
            VStack {
                Spacer()
                ContentUnavailableView(
                    "空文件夹",
                    systemImage: "folder",
                    description: Text("这个文件夹还没有文件")
                )
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}