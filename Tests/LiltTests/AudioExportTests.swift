import XCTest
import AVFoundation
import LiltCore
@testable import Lilt

final class AudioExportTests: XCTestCase {
    func testExportJoinsAllFramesAndReplacesExistingFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try ReadingStore(directory: root)
        var reading = Reading(text: "Hello again", source: "test", voice: "af_heart")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1))
        for index in 0..<2 {
            let chunk = SpeechChunk(key: "chunk\(index)", durationMs: 1000, words: [], charOffset: index * 6)
            let file = try AVAudioFile(forWriting: store.audioURL(for: chunk), settings: format.settings)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 24000))
            buffer.frameLength = 24000
            for n in 0..<24000 { buffer.floatChannelData![0][n] = Float(index + 1) * 0.1 }
            try file.write(from: buffer)
            reading.chunks.append(chunk)
        }
        reading.complete = true
        let output = root.appendingPathComponent("reading.wav")
        try Data([0]).write(to: output)
        try AudioExport.write(reading, from: store, to: output)
        let file = try AVAudioFile(forReading: output)
        XCTAssertEqual(file.length, 48000)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 48000))
        try file.read(into: buffer)
        XCTAssertEqual(buffer.floatChannelData![0][0], 0.1, accuracy: 0.0001)
        XCTAssertEqual(buffer.floatChannelData![0][24000], 0.2, accuracy: 0.0001)
        reading.complete = false
        XCTAssertThrowsError(try AudioExport.write(reading, from: store, to: output))
    }
}
