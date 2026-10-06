import XCTest
import AVFoundation
import Combine
import LiltCore
@testable import Lilt

final class AppModelPlaybackTests: XCTestCase {
    @MainActor func testCompletionAdvancesPastFractionalBoundaryAndStopsAtTheEnd() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try AppModel(directory: root)
        defer { model.shutdown() }
        model.playback.speed = 1
        var reading = Reading(text: "One two three", source: "Test", voice: "af_heart")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1))
        for (index, frames) in [507_000, 475_200, 378_000].enumerated() {
            let chunk = SpeechChunk(key: "chunk\(index)", durationMs: Double(frames) * 1000 / 24_000, words: [
                WordTiming(charIndex: index * 4, charLength: 3, startMs: 0, endMs: 500)
            ], charOffset: index * 4)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
            buffer.frameLength = AVAudioFrameCount(frames)
            buffer.floatChannelData![0].update(repeating: 0, count: frames)
            let file = try AVAudioFile(forWriting: model.store.audioURL(for: chunk), settings: format.settings)
            try file.write(from: buffer)
            reading.chunks.append(chunk)
        }
        reading.complete = true
        model.current = reading
        let boundary = reading.chunks.prefix(2).reduce(0) { $0 + $1.durationMs / 1000 }
        let advanced = expectation(description: "Third chunk starts")
        var subscription = model.playback.$activeRange.first { $0?.location == 8 }.sink { _ in advanced.fulfill() }
        model.seek(to: boundary - 0.05, play: true)
        await fulfillment(of: [advanced], timeout: 3)
        XCTAssertEqual(model.playback.activeRange?.location, 8)
        XCTAssertEqual(model.playback.position, boundary, accuracy: 0.1)
        XCTAssertTrue(model.playback.isPlaying)
        subscription.cancel()

        let finished = expectation(description: "Reading finishes")
        subscription = model.$status.first { $0 == "All read. Take a breath." }.sink { _ in finished.fulfill() }
        model.seek(to: reading.duration - 0.05, play: true)
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertFalse(model.playback.isPlaying)
        XCTAssertEqual(model.playback.position, reading.duration, accuracy: 0.01)
        XCTAssertNil(model.playback.activeRange)
        subscription.cancel()
    }
}
