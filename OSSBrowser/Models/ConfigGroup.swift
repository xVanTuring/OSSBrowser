//
//  ConfigGroup.swift
//  OSSBrowser
//
//  配置分组。只保存名称与顺序；配置归属哪个分组由 ConfigurationManager 单独记录，
//  这样 OSSConfiguration（存于钥匙串）的结构不需要改动。
//

import Foundation

struct ConfigGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
