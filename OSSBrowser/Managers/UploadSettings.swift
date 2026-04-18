//
//  UploadSettings.swift
//  OSSBrowser
//

import Foundation
import Combine

@MainActor
final class UploadSettings: ObservableObject {
    static let shared = UploadSettings()

    static let defaultPartSize: Int64 = 20 * 1024 * 1024          // 20 MB
    static let defaultMultipartThreshold: Int64 = 100 * 1024 * 1024
    static let defaultMaxConcurrency: Int = 5
    static let defaultMaxPartRetry: Int = 3

    private enum Key {
        static let partSize = "upload.partSize"
        static let multipartThreshold = "upload.multipartThreshold"
        static let maxConcurrency = "upload.maxConcurrency"
        static let maxPartRetry = "upload.maxPartRetry"
    }

    private let defaults = UserDefaults.standard

    @Published var partSize: Int64 {
        didSet { defaults.set(Int(partSize), forKey: Key.partSize) }
    }

    @Published var multipartThreshold: Int64 {
        didSet { defaults.set(Int(multipartThreshold), forKey: Key.multipartThreshold) }
    }

    @Published var maxConcurrency: Int {
        didSet { defaults.set(maxConcurrency, forKey: Key.maxConcurrency) }
    }

    @Published var maxPartRetry: Int {
        didSet { defaults.set(maxPartRetry, forKey: Key.maxPartRetry) }
    }

    private init() {
        let storedPart = defaults.object(forKey: Key.partSize) as? Int ?? 0
        self.partSize = storedPart > 0 ? Int64(storedPart) : Self.defaultPartSize

        let storedThreshold = defaults.object(forKey: Key.multipartThreshold) as? Int ?? 0
        self.multipartThreshold = storedThreshold > 0 ? Int64(storedThreshold) : Self.defaultMultipartThreshold

        let storedConc = defaults.object(forKey: Key.maxConcurrency) as? Int ?? 0
        self.maxConcurrency = storedConc > 0 ? storedConc : Self.defaultMaxConcurrency

        let storedRetry = defaults.object(forKey: Key.maxPartRetry) as? Int ?? -1
        self.maxPartRetry = storedRetry >= 0 ? storedRetry : Self.defaultMaxPartRetry
    }

    struct Snapshot: Sendable {
        let partSize: Int64
        let multipartThreshold: Int64
        let maxConcurrency: Int
        let maxPartRetry: Int
    }

    func snapshot() -> Snapshot {
        Snapshot(
            partSize: partSize,
            multipartThreshold: multipartThreshold,
            maxConcurrency: maxConcurrency,
            maxPartRetry: maxPartRetry
        )
    }
}
