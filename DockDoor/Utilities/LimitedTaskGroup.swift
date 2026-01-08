import Foundation

/// Structured concurrency utilities for limiting concurrent task execution.
enum LimitedConcurrency {
    /// Process items concurrently with a maximum parallelism limit, collecting results.
    /// - Parameters:
    ///   - items: The items to process.
    ///   - maxConcurrent: Maximum number of concurrent operations.
    ///   - operation: The async operation to perform on each item.
    /// - Returns: Array of results from all operations.
    static func map<T: Sendable, R: Sendable>(
        _ items: [T],
        maxConcurrent: Int,
        operation: @Sendable @escaping (T) async throws -> R
    ) async throws -> [R] {
        guard !items.isEmpty else { return [] }
        let concurrency = max(1, min(maxConcurrent, items.count))

        return try await withThrowingTaskGroup(of: R.self) { group in
            var results: [R] = []
            results.reserveCapacity(items.count)
            var iterator = items.makeIterator()

            for _ in 0 ..< concurrency {
                if let item = iterator.next() {
                    group.addTask { try await operation(item) }
                }
            }

            while let result = try await group.next() {
                results.append(result)
                if let item = iterator.next() {
                    group.addTask { try await operation(item) }
                }
            }

            return results
        }
    }

    /// Process items concurrently with a maximum parallelism limit, discarding results.
    /// - Parameters:
    ///   - items: The items to process.
    ///   - maxConcurrent: Maximum number of concurrent operations.
    ///   - operation: The async operation to perform on each item.
    static func forEach<T: Sendable>(
        _ items: [T],
        maxConcurrent: Int,
        operation: @Sendable @escaping (T) async throws -> Void
    ) async throws {
        guard !items.isEmpty else { return }
        let concurrency = max(1, min(maxConcurrent, items.count))

        try await withThrowingTaskGroup(of: Void.self) { group in
            var iterator = items.makeIterator()

            for _ in 0 ..< concurrency {
                if let item = iterator.next() {
                    group.addTask { try await operation(item) }
                }
            }

            while try await group.next() != nil {
                if let item = iterator.next() {
                    group.addTask { try await operation(item) }
                }
            }
        }
    }

    /// Process items concurrently with a maximum parallelism limit, continuing on errors.
    /// - Parameters:
    ///   - items: The items to process.
    ///   - maxConcurrent: Maximum number of concurrent operations.
    ///   - operation: The async operation to perform on each item.
    static func forEachNonThrowing<T: Sendable>(
        _ items: [T],
        maxConcurrent: Int,
        operation: @Sendable @escaping (T) async throws -> Void
    ) async {
        guard !items.isEmpty else { return }
        let concurrency = max(1, min(maxConcurrent, items.count))

        await withTaskGroup(of: Void.self) { group in
            var iterator = items.makeIterator()

            for _ in 0 ..< concurrency {
                if let item = iterator.next() {
                    group.addTask {
                        do {
                            try await operation(item)
                        } catch {
                            DebugLogger.log("LimitedConcurrency", details: "Task failed: \(error.localizedDescription)")
                        }
                    }
                }
            }

            while await group.next() != nil {
                if let item = iterator.next() {
                    group.addTask {
                        do {
                            try await operation(item)
                        } catch {
                            DebugLogger.log("LimitedConcurrency", details: "Task failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}
