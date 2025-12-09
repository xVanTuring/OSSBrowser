//
//  OSSConfiguration.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import Foundation

struct OSSConfiguration: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let accessKeyId: String
    let accessKeySecret: String
    let region: String
    let endpoint: String?

    init(name: String, accessKeyId: String, accessKeySecret: String, region: String, endpoint: String? = nil) {
        self.id = UUID()
        self.name = name
        self.accessKeyId = accessKeyId
        self.accessKeySecret = accessKeySecret
        self.region = region
        self.endpoint = endpoint
    }

    // 用于编辑时保留原有 ID
    init(id: UUID, name: String, accessKeyId: String, accessKeySecret: String, region: String, endpoint: String? = nil) {
        self.id = id
        self.name = name
        self.accessKeyId = accessKeyId
        self.accessKeySecret = accessKeySecret
        self.region = region
        self.endpoint = endpoint
    }

    // 生成默认的 endpoint
    var defaultEndpoint: String {
        return "https://oss-\(region).aliyuncs.com"
    }
}