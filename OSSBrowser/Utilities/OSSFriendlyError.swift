//
//  OSSFriendlyError.swift
//  OSSBrowser
//
//  将常见的连接/鉴权错误翻译成更友好的中文提示；无法识别时回退到 localizedDescription。
//

import Foundation

enum OSSFriendlyError {
    /// 返回对用户更友好的错误描述
    static func message(for error: Error) -> String {
        // OSSService.connect 会把 SDK 的 ClientError 转成 OSSError.ossError(code:message:)
        if let ossError = error as? OSSError,
           case let .ossError(code, message) = ossError {
            switch code {
            case "InvalidAccessKeyId":
                return "Access Key ID 无效，请检查后重试。"
            case "SignatureDoesNotMatch":
                return "Access Key Secret 不正确（签名校验失败），请检查后重试。"
            case "AccessDenied", "Forbidden":
                return "访问被拒绝，请确认该账号是否具备访问权限。"
            case "InvalidBucketName", "NoSuchBucket":
                return message ?? error.localizedDescription
            default:
                return error.localizedDescription
            }
        }

        // 网络类错误（如无法连接、超时、找不到主机等）
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "网络连接失败，请检查网络连接或自定义 Endpoint 是否正确。"
        }

        return error.localizedDescription
    }
}
