//
//  KeychainManager.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import Foundation
import Security

class KeychainManager {
    private let service = "tech.xvanturing.OSSBrowser"

    func saveConfiguration(_ config: OSSConfiguration) throws {
        let data = try JSONEncoder().encode(config)
        print("Saving configuration: \(config.name)")

        // 先尝试更新或添加
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: config.id.uuidString,
            kSecValueData as String: data
        ]

        // 先尝试更新
        var status = SecItemUpdate(updateQuery as CFDictionary, [
            kSecValueData as String: data
        ] as CFDictionary)

        // 如果更新失败（可能不存在），则添加新的
        if status == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: config.id.uuidString,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]

            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            print("Failed to save configuration, status: \(status)")
            throw KeychainError.saveError(status)
        }

        print("Configuration saved successfully")
    }

    func loadConfigurations() throws -> [OSSConfiguration] {
        // 使用不同的方法：先查询所有账号，然后逐个获取
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            print("No configurations found in keychain")
            return []
        }

        guard status == errSecSuccess else {
            print("Failed to load from keychain, status: \(status)")
            throw KeychainError.loadError(status)
        }

        var configurations: [OSSConfiguration] = []

        guard let items = result as? [[String: Any]] else {
            print("Unexpected result format from keychain")
            throw KeychainError.loadError(-1)
        }

        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  UUID(uuidString: account) != nil else {
                print("Skipping item with invalid account")
                continue
            }

            // 获取具体的数据
            let dataQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true
            ]

            var dataResult: CFTypeRef?
            let dataStatus = SecItemCopyMatching(dataQuery as CFDictionary, &dataResult)

            guard dataStatus == errSecSuccess,
                  let data = dataResult as? Data else {
                print("Failed to get data for account: \(account)")
                continue
            }

            do {
                let config = try JSONDecoder().decode(OSSConfiguration.self, from: data)
                configurations.append(config)
                print("Loaded configuration: \(config.name)")
            } catch {
                print("Failed to decode configuration: \(error)")
            }
        }

        print("Total loaded configurations: \(configurations.count)")
        return configurations
    }

    func deleteConfiguration(_ id: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            print("Configuration deleted successfully")
        } else if status != errSecItemNotFound {
            print("Failed to delete configuration, status: \(status)")
        }
    }
}

enum KeychainError: LocalizedError {
    case saveError(OSStatus)
    case loadError(OSStatus)
    case deleteError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveError(let status):
            return "Failed to save to keychain: \(status)"
        case .loadError(let status):
            return "Failed to load from keychain: \(status)"
        case .deleteError(let status):
            return "Failed to delete from keychain: \(status)"
        }
    }
}