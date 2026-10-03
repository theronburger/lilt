import XCTest
import AVFoundation
import LiltCore
@testable import Lilt

final class AudioPlaybackTests: XCTestCase {
    @MainActor func testAudioClockSeekingAndCompletionStayInSync() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 12_000))
        buffer.frameLength = 12_000
        buffer.floatChannelData![0].update(repeating: 0, count: 12_000)
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        let playback = AudioPlayback()
        let chunk = SpeechChunk(key: "test", durationMs: 500, words: [
            WordTiming(charIndex: 12, charLength: 4, startMs: 100, endMs: 450)
        ], charOffset: 12)
        try playback.load(chunk, url: url, offset: 2, at: 0.2, play: false)
        XCTAssertEqual(playback.position, 2.2, accuracy: 0.02)
        XCTAssertEqual(playback.activeRange?.location, 12)
        let completion = expectation(description: "Audio finished")
        playback.onBoundary = { completion.fulfill() }
        playback.resume()
        await fulfillment(of: [completion], timeout: 3)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(playback.isPlaying)
        XCTAssertNil(playback.activeRange)
        XCTAssertEqual(playback.position, 2.5, accuracy: 0.01)
        playback.pause()
        XCTAssertEqual(playback.position, 2.5, accuracy: 0.01)
        playback.stop()
    }
}
