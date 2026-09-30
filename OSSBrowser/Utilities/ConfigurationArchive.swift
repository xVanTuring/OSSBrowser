//
//  ConfigurationArchive.swift
//  OSSBrowser
//
//  配置导入导出文件（.ossconfig）。内容为 JSON 外壳 + 加密数据：
//  用 PBKDF2-SHA256 从密码派生 256 位密钥，再用 AES-GCM 加密配置与分组。
//  AES-GCM 自带完整性校验，密码错误或文件被改动都会解密失败。
//

import Foundation
import CryptoKit
import CommonCrypto
import UniformTypeIdentifiers

enum ConfigurationArchive {
    /// 文件扩展名
    static let fileExtension = "ossconfig"
    /// 文件类型，声明在 Config/OSSBrowser-Info.plist
    static let contentType = UTType(exportedAs: "tech.xvanturing.ossconfig", conformingTo: .json)

    /// 加密前的内容
    struct Payload: Codable {
        var groups: [ConfigGroup]
        var items: [Item]
    }

    struct Item: Codable {
        var configuration: OSSConfiguration
        /// 所属分组；nil 表示未分组
        var groupId: UUID?
    }

    enum ArchiveError: LocalizedError {
        case invalidFile
        case unsupportedVersion(Int)
        case wrongPassword
        case keyDerivationFailed

        var errorDescription: String? {
            switch self {
            case .invalidFile: return "不是有效的 OSSBrowser 配置文件"
            case .unsupportedVersion(let v): return "不支持的文件版本（\(v)），请升级 OSSBrowser 后再导入"
            case .wrongPassword: return "密码错误或文件已损坏"
            case .keyDerivationFailed: return "密钥生成失败"
            }
        }
    }

    // MARK: - 文件外壳

    private static let formatName = "ossbrowser-config"
    private static let currentVersion = 1
    private static let iterations = 200_000

    private struct Envelope: Codable {
        var format: String
        var version: Int
        var kdf: String
        var iterations: Int
        var salt: Data
        /// AES-GCM 合并格式：nonce + 密文 + 校验标签
        var sealed: Data
    }

    // MARK: - 加密 / 解密

    static func encrypt(_ payload: Payload, password: String) throws -> Data {
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let key = try deriveKey(password: password, salt: salt, iterations: iterations)
        let plain = try JSONEncoder().encode(payload)
        guard let sealed = try AES.GCM.seal(plain, using: key).combined else {
            throw ArchiveError.invalidFile
        }
        let envelope = Envelope(
            format: formatName,
            version: currentVersion,
            kdf: "pbkdf2-sha256",
            iterations: iterations,
            salt: salt,
            sealed: sealed
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    static func decrypt(_ data: Data, password: String) throws -> Payload {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.format == formatName
        else {
            throw ArchiveError.invalidFile
        }
        guard envelope.version <= currentVersion else {
            throw ArchiveError.unsupportedVersion(envelope.version)
        }
        let key = try deriveKey(password: password, salt: envelope.salt, iterations: envelope.iterations)
        let plain: Data
        do {
            plain = try AES.GCM.open(AES.GCM.SealedBox(combined: envelope.sealed), using: key)
        } catch {
            throw ArchiveError.wrongPassword
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: plain) else {
            throw ArchiveError.invalidFile
        }
        return payload
    }

    // MARK: - PBKDF2

    private static func deriveKey(password: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        let passwordBytes = Array(password.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let status = salt.withUnsafeBytes { saltBuffer in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                password, passwordBytes.count,
                saltBuffer.bindMemory(to: UInt8.self).baseAddress, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(iterations),
                &derived, derived.count
            )
        }
        guard status == kCCSuccess else { throw ArchiveError.keyDerivationFailed }
        return SymmetricKey(data: derived)
    }
}
