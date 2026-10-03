import XCTest
import AppKit
import SwiftUI
import AVFoundation
import LiltCore
@testable import Lilt

final class CaptureCanvasTests: XCTestCase {
    @MainActor func testRealOCRBoxesMatchRenderedPixelsAndClickableWords() async throws {
        let image = NSImage(size: NSSize(width: 640, height: 180))
        image.lockFocus()
        NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.90, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 640, height: 180).fill()
        ("Keep the words right where they are." as NSString).draw(at: NSPoint(x: 24, y: 115), withAttributes: [
            .font: NSFont.systemFont(ofSize: 26, weight: .semibold), .foregroundColor: NSColor.labelColor
        ])
        ("The original fonts and spacing stay with the image." as NSString).draw(at: NSPoint(x: 24, y: 75), withAttributes: [
            .font: NSFont.systemFont(ofSize: 20), .foregroundColor: NSColor.black
        ])
        ("Click any word to listen from there." as NSString).draw(at: NSPoint(x: 24, y: 35), withAttributes: [
            .font: NSFont.systemFont(ofSize: 20), .foregroundColor: NSColor.black
        ])
        image.unlockFocus()
        let pixels = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let recognized = try await TextRecognition.recognize(pixels)
        let target = try XCTUnwrap(recognized.words.first { (recognized.text as NSString).substring(with: $0.range) == "words" })
        let canvas = CaptureCanvas(frame: NSRect(x: 0, y: 0, width: 640, height: 180))
        canvas.image = image
        canvas.text = recognized.text
        canvas.words = recognized.words
        canvas.activeRange = target.range
        canvas.rebuildAccessibility()
        let rectangle = target.rectangle(in: canvas.bounds)
        XCTAssertEqual(canvas.word(at: NSPoint(x: rectangle.midX, y: rectangle.midY)), target)
        XCTAssertNil(canvas.word(at: NSPoint(x: 5, y: 5)))
        canvas.setFrameSize(NSSize(width: 320, height: 90))
        let scaled = target.rectangle(in: canvas.bounds)
        XCTAssertEqual(canvas.word(at: NSPoint(x: scaled.midX, y: scaled.midY)), target)
        XCTAssertEqual(scaled.width, rectangle.width / 2, accuracy: 0.01)

        let output = ProcessInfo.processInfo.environment["LILT_TEST_PREVIEW"]
        if let output {
            canvas.setFrameSize(NSSize(width: 640, height: 180))
            let bitmap = try XCTUnwrap(canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds))
            canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: output))
            try renderReaderPreview(image: image, recognized: recognized, activeWord: target, output: output + ".reader.png")
        }
    }

    @MainActor private func renderReaderPreview(image: NSImage, recognized: CapturedText, activeWord: CapturedWord, output: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = try AppModel(directory: directory)
        model.captureImage = image
        var reading = Reading(text: recognized.text, source: "Screen capture", voice: "af_heart")
        reading.snapshot = CaptureSnapshot(pointSize: image.size, words: recognized.words)
        let chunk = SpeechChunk(key: "preview", durationMs: 1000, words: [
            WordTiming(charIndex: activeWord.charIndex, charLength: activeWord.charLength, startMs: 0, endMs: 1000)
        ], charOffset: 0)
        reading.chunks = [chunk]
        reading.complete = true
        model.current = reading
        let audio = directory.appendingPathComponent("preview.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1))
        let samples = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 24_000))
        samples.frameLength = 24_000
        samples.floatChannelData![0].update(repeating: 0, count: 24_000)
        do { try AVAudioFile(forWriting: audio, settings: format.settings).write(from: samples) }
        try model.playback.load(chunk, url: audio, offset: 0, at: 0.2, play: false)
        defer { model.playback.stop() }
        let host = NSHostingView(rootView: CaptureReaderView(model: model, playback: model.playback))
        let frame = NSRect(x: 0, y: 0, width: 672, height: 212)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.frame = frame
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: output))
    }
}
