//
//  TransferShared.swift
//  OSSBrowser
//

import Foundation

// MARK: - Byte Counter

nonisolated final class TransferByteCounter: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var _total: Int64 = 0

    func add(_ n: Int64) {
        lock.lock()
        _total += n
        lock.unlock()
    }

    var total: Int64 {
        lock.lock()
        let v = _total
        lock.unlock()
        return v
    }
}

// MARK: - Progress Ticker

actor TransferProgressTicker {
    private let counter: TransferByteCounter
    private let onTick: @Sendable (Int64) async -> Void
    private let intervalNanos: UInt64
    private var tickTask: Task<Void, Never>?

    init(
        counter: TransferByteCounter,
        intervalMillis: UInt64 = 200,
        onTick: @escaping @Sendable (Int64) async -> Void
    ) {
        self.counter = counter
        self.onTick = onTick
        self.intervalNanos = intervalMillis * 1_000_000
    }

    func start() {
        tickTask?.cancel()
        tickTask = Task { [counter, onTick, intervalNanos] in
            while !Task.isCancelled {
                let current = counter.total
                await onTick(current)
                try? await Task.sleep(nanoseconds: intervalNanos)
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }
}

// MARK: - URLSession Task Box (for cancellation bridging)

nonisolated final class URLTaskBox: @unchecked Sendable {
    nonisolated(unsafe) var task: URLSessionTask?
}
