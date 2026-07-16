//
//  OSSRegionPicker.swift
//  OSSBrowser
//
//  区域（Region）选择的共享数据与下拉组件，供配置编辑面板与连接测试页复用。
//

import SwiftUI

/// OSS 支持的地域项
struct OSSRegion: Identifiable, Hashable {
    let code: String
    let displayName: String

    var id: String { code }

    /// 全部可选地域（与阿里云 OSS 常用地域保持一致）
    static let all: [OSSRegion] = [
        OSSRegion(code: "cn-hangzhou", displayName: "华东1（杭州）"),
        OSSRegion(code: "cn-shanghai", displayName: "华东2（上海）"),
        OSSRegion(code: "cn-qingdao", displayName: "华北1（青岛）"),
        OSSRegion(code: "cn-beijing", displayName: "华北2（北京）"),
        OSSRegion(code: "cn-zhangjiakou", displayName: "华北3（张家口）"),
        OSSRegion(code: "cn-huhehaote", displayName: "华北5（呼和浩特）"),
        OSSRegion(code: "cn-shenzhen", displayName: "华南1（深圳）"),
        OSSRegion(code: "cn-chengdu", displayName: "西南1（成都）"),
        OSSRegion(code: "cn-hongkong", displayName: "中国香港"),
        OSSRegion(code: "us-west-1", displayName: "美国西部1（硅谷）"),
        OSSRegion(code: "us-east-1", displayName: "美国东部1（弗吉尼亚）"),
        OSSRegion(code: "ap-southeast-1", displayName: "新加坡"),
        OSSRegion(code: "ap-northeast-1", displayName: "日本（东京）"),
        OSSRegion(code: "eu-central-1", displayName: "德国（法兰克福）"),
        OSSRegion(code: "eu-west-1", displayName: "英国（伦敦）"),
        OSSRegion(code: "ap-southeast-2", displayName: "澳大利亚（悉尼）"),
    ]
}

/// 复用的地域下拉选择组件
struct OSSRegionPicker: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(OSSRegion.all) { region in
                Text(region.displayName).tag(region.code)
            }
        }
    }
}
