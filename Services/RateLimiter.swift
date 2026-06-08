import Foundation

final class RateLimiter {
    private var lastExecution: [String: Date] = [:]
    private let lock = NSLock()

    func allows(_ key: String, interval: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        if let last = lastExecution[key], now.timeIntervalSince(last) < interval {
            return false
        }

        lastExecution[key] = now
        return true
    }
}

