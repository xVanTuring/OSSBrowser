//
//  ConfigurationManager.swift
//  OSSBrowser
//
//  Created by xvan on 2025/12/9.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ConfigurationManager: ObservableObject {
    @Published var configurations: [OSSConfiguration] = []

    private let keychainManager = KeychainManager()

    init() {
        print("ConfigurationManager: Initializing...")

        // 运行 Keychain 测试（仅在 Debug 模式）
//        #if DEBUG
//        KeychainTest.runTest()
//        #endif

        loadConfigurations()
        print("ConfigurationManager: Initialized with \(configurations.count) configurations")
    }

    func addConfiguration(_ config: OSSConfiguration) {
        print("ConfigurationManager: Adding configuration \(config.name)")
        configurations.append(config)
        saveConfiguration(config)
        print("ConfigurationManager: Total configurations after adding: \(configurations.count)")
    }

    func updateConfiguration(_ config: OSSConfiguration) {
        print("ConfigurationManager: Updating configuration \(config.name) with id \(config.id)")
        if let index = configurations.firstIndex(where: { $0.id == config.id }) {
            print("ConfigurationManager: Found configuration at index \(index)")
            configurations[index] = config
            saveConfiguration(config)
            print("ConfigurationManager: Configuration updated and saved")
        } else {
            print("ConfigurationManager: Configuration not found!")
        }
    }

    func deleteConfiguration(_ config: OSSConfiguration) {
        configurations.removeAll { $0.id == config.id }
        keychainManager.deleteConfiguration(config.id)
    }

    private func saveConfiguration(_ config: OSSConfiguration) {
        do {
            try keychainManager.saveConfiguration(config)
        } catch {
            print("Failed to save configuration: \(error)")
        }
    }

    private func loadConfigurations() {
        do {
            configurations = try keychainManager.loadConfigurations()
        } catch {
            print("Failed to load configurations: \(error)")
        }
    }
}
