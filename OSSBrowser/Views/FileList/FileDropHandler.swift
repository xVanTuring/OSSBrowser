//
//  FileDropHandler.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/14.
//

import SwiftUI

struct FileDropHandler {
    let onDropFile: (URL) -> Void?
    let onDropFolder: (URL) -> Void?

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url else { return }
                    DispatchQueue.main.async {
                        if isDirectory(at: url) {
                            onDropFolder(url)
                        } else {
                            onDropFile(url)
                        }
                    }
                }
            }
        }
        return true
    }

    private func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
}