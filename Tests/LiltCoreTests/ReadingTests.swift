import XCTest
@testable import LiltCore

final class ReadingTests: XCTestCase {
    func testSeekingAcrossChunksAndPauses() {
        var reading = Reading(text: "Hello world. Hello again.", source: "Test", voice: "af_heart")
        reading.chunks = [
            SpeechChunk(key: "a", durationMs: 1200, words: [
                WordTiming(charIndex: 0, charLength: 5, startMs: 0, endMs: 400),
                WordTiming(charIndex: 6, charLength: 5, startMs: 500, endMs: 1000)
            ], charOffset: 0),
            SpeechChunk(key: "b", durationMs: 1100, words: [
                WordTiming(charIndex: 13, charLength: 5, startMs: 0, endMs: 400),
                WordTiming(charIndex: 19, charLength: 5, startMs: 500, endMs: 1000)
            ], charOffset: 13)
        ]
        XCTAssertEqual(reading.time(forCharacter: 14), 1.2)
        XCTAssertEqual(reading.time(forCharacter: 21), 1.7)
        XCTAssertNil(reading.time(forCharacter: 12))
        XCTAssertEqual(reading.location(at: 1.2)?.index, 1)
        XCTAssertEqual(reading.location(at: 1.7)!.seconds, 0.5, accuracy: 0.0001)
        XCTAssertEqual(reading.location(at: 99)!.seconds, 1.1, accuracy: 0.0001)
        XCTAssertNil(reading.chunks[0].activeWord(at: 0.45))
        XCTAssertEqual(reading.chunks[0].activeWord(at: 0.55)?.charIndex, 6)
    }

    func testUTF16OffsetsPreserveEmojiAndAccents() {
        let text = "Hi 👋 café!"
        let range = WordTiming(charIndex: 6, charLength: 4, startMs: 0, endMs: 300).range
        XCTAssertEqual((text as NSString).substring(with: range), "café")
    }

    func testHistoryRoundTripAndSharedAudioPruning() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReadingStore(directory: directory)
        var reading = Reading(text: "Saved reading", source: "Test", voice: "af_heart")
        reading.chunks = [SpeechChunk(key: "shared", durationMs: 1000, words: [], charOffset: 0)]
        reading.complete = true
        reading.position = 0.4
        try Data().write(to: store.audioURL(for: reading.chunks[0]))
        let orphan = store.audioDirectory.appendingPathComponent("orphan.wav")
        try Data().write(to: orphan)
        try store.save([reading])
        let loaded = try store.load()
        XCTAssertEqual(loaded.first?.id, reading.id)
        XCTAssertEqual(loaded.first?.position, 0.4)
        XCTAssertTrue(store.hasAudio(for: loaded[0]))
        try store.pruneAudio(keeping: loaded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
        XCTAssertTrue(store.hasAudio(for: loaded[0]))
    }
}
