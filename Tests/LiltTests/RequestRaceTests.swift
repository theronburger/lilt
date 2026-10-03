import XCTest
@testable import Lilt

private actor Attempts {
    var next = 0
    var cancelled = 0
    func take() -> Int { defer { next += 1 }; return next }
    func didCancel() { cancelled += 1 }
}
final class RequestRaceTests: XCTestCase {
    func testRejectedFastResponseDoesNotWinAndSlowLoserIsCancelled() async throws {
        let state = Attempts()
        let result = try await RequestRace.first(attempts: 3) {
            switch await state.take() {
            case 0: throw FilterError.alignment
            case 1: try await Task.sleep(for: .milliseconds(20)); return "Valid reading"
            default:
                do { try await Task.sleep(for: .seconds(10)); return "Slow" }
                catch { await state.didCancel(); throw error }
            }
        }
        XCTAssertEqual(result, "Valid reading")
        let cancelled = await state.cancelled
        XCTAssertEqual(cancelled, 1)
    }
    func testAllFailuresPropagateAndAttemptsAreBounded() async {
        let state = Attempts()
        do {
            let _: String = try await RequestRace.first(attempts: 100) {
                _ = await state.take(); throw FilterError.http(401)
            }
            XCTFail("Expected error")
        } catch FilterError.http(401) {} catch { XCTFail("Unexpected error: \(error)") }
        let count = await state.next
        XCTAssertEqual(count, 3)
    }
    func testCallerCancellationStopsEveryAttempt() async throws {
        let state = Attempts()
        let task = Task {
            try await RequestRace.first(attempts: 3) {
                _ = await state.take()
                do { try await Task.sleep(for: .seconds(10)); return "Unexpected" }
                catch { await state.didCancel(); throw error }
            }
        }
        try await Task.sleep(for: .milliseconds(30))
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch is CancellationError {} catch { XCTFail("Unexpected error") }
        let count = await state.cancelled
        XCTAssertEqual(count, 3)
    }
}
