//
//  FavoritePath.swift
//  OSSBrowser
//

import Foundation

/// 收藏的 OSS 路径（按配置 + Bucket 分组）
struct FavoritePath: Identifiable, Codable, Hashable {
    let id: UUID
    let configId: UUID
    let bucketName: String
    /// 收藏的目录路径，"" 表示 Bucket 根目录
    let path: String
    let displayName: String
    let createdAt: Date

    init(configId: UUID, bucketName: String, path: String) {
        self.id = UUID()
        self.configId = configId
        self.bucketName = bucketName
        self.path = path
        self.displayName = FavoritePath.defaultDisplayName(bucketName: bucketName, path: path)
        self.createdAt = Date()
    }
}

extension FavoritePath {
    static func defaultDisplayName(bucketName: String, path: String) -> String {
        guard !path.isEmpty else { return bucketName }
        return path.split(separator: "/").last.map(String.init) ?? path
    }
}
