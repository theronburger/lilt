import Foundation

/// Only a fully validated success wins. Cancellation propagates to every request.
enum RequestRace {
    static func first<Value: Sendable>(attempts: Int, operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
        try Task.checkCancellation()
        return try await withThrowingTaskGroup(of: Result<Value, Error>.self) { group in
            for _ in 0..<max(1, min(3, attempts)) {
                group.addTask {
                    do { return .success(try await operation()) }
                    catch { return .failure(error) }
                }
            }
            defer { group.cancelAll() }
            var failure: Error = FilterError.request
            for try await result in group {
                try Task.checkCancellation()
                switch result {
                case .success(let value): return value
                case .failure(let error): failure = error
                }
            }
            throw failure
        }
    }
}
