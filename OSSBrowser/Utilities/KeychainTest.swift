//
//  KeychainTest.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import Foundation

class KeychainTest {
    static func runTest() {
        print("\n=== Keychain Test ===")

        let keychainManager = KeychainManager()
        let testConfigName = "Test Config (Temporary)"

        // 先清理之前的测试配置
        print("\n0. Cleaning up previous test configurations...")
        do {
            let existingConfigs = try keychainManager.loadConfigurations()
            for config in existingConfigs {
                if config.name.contains("Test Config") || config.name == "测试" {
                    keychainManager.deleteConfiguration(config.id)
                    print("   Deleted: \(config.name)")
                }
            }
        } catch {
            print("   Warning: Failed to clean up: \(error)")
        }

        // Test 1: 创建测试配置
        let testConfig = OSSConfiguration(
            name: testConfigName,
            accessKeyId: "test_ak",
            accessKeySecret: "test_sk",
            region: "cn-hangzhou"
        )

        print("\n1. Testing save...")
        do {
            try keychainManager.saveConfiguration(testConfig)
            print("✅ Save successful")
        } catch {
            print("❌ Save failed: \(error)")
            return
        }

        // Test 2: 读取配置
        print("\n2. Testing load...")
        do {
            let configs = try keychainManager.loadConfigurations()
            print("✅ Load successful, count: \(configs.count)")
            for config in configs {
                print("   - \(config.name)")
            }
        } catch {
            print("❌ Load failed: \(error)")
            return
        }

        // Test 3: 删除测试配置
        print("\n3. Cleaning up test configuration...")
        keychainManager.deleteConfiguration(testConfig.id)

        // Test 4: 再次读取确认删除
        print("\n4. Testing load after delete...")
        do {
            let configs = try keychainManager.loadConfigurations()
            print("✅ Load successful after delete, count: \(configs.count)")
        } catch {
            print("❌ Load failed: \(error)")
        }

        print("\n=== Keychain Test Complete ===\n")
    }
}