import XCTest
@testable import LiltCore

final class HistoryRetentionTests: XCTestCase {
    func testExpiryKeepsCurrentBoundaryAndSharedAudio() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try ReadingStore(directory: root)
        let now = Date(timeIntervalSince1970: 2_000_000)
        func reading(age: Double) -> Reading {
            var r = Reading(text: "A reading", source: "test", voice: "af_heart")
            r.createdAt = now.addingTimeInterval(-age * 86400)
            return r
        }
        var old = reading(age: 8), current = reading(age: 9), boundary = reading(age: 7)
        let oldest = reading(age: 100)
        let shared = SpeechChunk(key: "shared", durationMs: 100, words: [], charOffset: 0)
        old.chunks = [shared]; boundary.chunks = [shared]
        current.chunks = [SpeechChunk(key: "current", durationMs: 100, words: [], charOffset: 0)]
        let all = [old, oldest, current, boundary]
        for r in all { try store.saveCapture(Data([1]), for: r.id) }
        try Data([1]).write(to: store.audioDirectory.appendingPathComponent("shared.wav"))
        try Data([1]).write(to: store.audioDirectory.appendingPathComponent("unused.wav"))
        let kept = try store.expire(all, after: 7, now: now, protecting: current.id)
        XCTAssertEqual(Set(kept.map(\.id)), Set([current.id, boundary.id]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.captureURL(for: old.id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.captureURL(for: oldest.id).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.audioDirectory.appendingPathComponent("shared.wav").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.audioDirectory.appendingPathComponent("unused.wav").path))
        XCTAssertEqual(try store.load().count, 2)
        XCTAssertEqual(try store.expire(all, after: 0, now: now).count, 4)
    }
    func testLegacyHistoryStillDecodesAfterFeatureRemoval() throws {
        let original = Reading(text: "Original title", source: "test", voice: "af_heart")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "customTitle")
        let decoded = try JSONDecoder().decode(Reading.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.title, "Original title")
        // A previously named or starred reading remains readable; a former star
        // no longer exempts the reading from the user's retention period.
        json["customTitle"] = "My title"; json["favourite"] = true
        let legacy = try JSONDecoder().decode(Reading.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.title, "My title")
        XCTAssertEqual(legacy.text, original.text)
    }
}
