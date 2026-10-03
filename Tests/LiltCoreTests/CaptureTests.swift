import XCTest
import CoreGraphics
@testable import LiltCore

final class CaptureTests: XCTestCase {
    func testHighlightTracksAspectFitAndRepeatedWordsByRange() {
        let first = CapturedWord(charIndex: 0, charLength: 5, bounds: CGRect(x: 0.1, y: 0.2, width: 0.2, height: 0.1))
        let second = CapturedWord(charIndex: 6, charLength: 5, bounds: CGRect(x: 0.5, y: 0.2, width: 0.2, height: 0.1))
        let image = CaptureLayout.imageRect(size: CGSize(width: 800, height: 400), in: CGRect(x: 0, y: 0, width: 400, height: 400))
        XCTAssertEqual(image, CGRect(x: 0, y: 100, width: 400, height: 200))
        XCTAssertEqual(second.rectangle(in: image), CGRect(x: 200, y: 140, width: 80, height: 20))
        XCTAssertFalse(first.overlaps(NSRange(location: 7, length: 3)))
        XCTAssertTrue(second.overlaps(NSRange(location: 7, length: 3)))
    }

    func testCaptureStaysAtItsOriginalPositionWithoutFooter() {
        let capture = CGRect(x: 140, y: 200, width: 600, height: 300)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = CaptureLayout.windowFrame(around: capture, visibleFrame: visible)
            .insetBy(dx: CaptureLayout.shadowInset, dy: CaptureLayout.shadowInset)
        XCTAssertEqual(frame.minX, capture.minX)
        XCTAssertEqual(frame.maxY, capture.maxY)
        XCTAssertEqual(frame.width, capture.width)
        XCTAssertEqual(frame.height, capture.height)
    }

    func testFrameFitsNegativeOriginDisplayAndLargeCapture() {
        let screen = CGRect(x: -1440, y: 180, width: 1440, height: 900)
        for capture in [CGRect(x: -1440, y: 180, width: 1440, height: 900),
                        CGRect(x: -10, y: 185, width: 10, height: 10)] {
            let frame = CaptureLayout.windowFrame(around: capture, visibleFrame: screen)
            XCTAssertTrue(screen.contains(frame))
            XCTAssertGreaterThan(frame.width, 0)
        }
    }

    func testDetachedControlsFitScreenWithoutMovingImage() {
        let screen = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        let image = CGRect(x: -1000, y: 300, width: 600, height: 300)
        let controls = CaptureLayout.controlsFrame(below: image, visibleFrame: screen)
        XCTAssertEqual(controls.maxY, image.minY - 6)
        XCTAssertEqual(controls.midX, image.midX)
        XCTAssertTrue(screen.contains(controls))
        let lowImage = CGRect(x: -300, y: 8, width: 280, height: 100)
        let above = CaptureLayout.controlsFrame(below: lowImage, visibleFrame: screen)
        XCTAssertGreaterThanOrEqual(above.minY, lowImage.maxY)
        XCTAssertTrue(screen.contains(above))
    }

    func testOldHistoryDecodesWithoutScreenshotAndNewCapturesPersist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReadingStore(directory: directory)
        var reading = Reading(text: "Hello", source: "Screen capture", voice: "af_heart")
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(reading)) as? [String: Any])
        legacy.removeValue(forKey: "snapshot")
        let old = try JSONDecoder().decode(Reading.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(old.snapshot)
        reading.snapshot = CaptureSnapshot(pointSize: CGSize(width: 600, height: 200), words: [
            CapturedWord(charIndex: 0, charLength: 5, bounds: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.2))
        ])
        try store.save([reading])
        try store.saveCapture(Data([1, 2, 3]), for: reading.id)
        let restored = try XCTUnwrap(store.load().first)
        XCTAssertEqual(restored.snapshot?.words, reading.snapshot?.words)
        XCTAssertEqual(restored.snapshot?.pointSize, reading.snapshot?.pointSize)
        XCTAssertEqual(try Data(contentsOf: store.captureURL(for: reading.id)), Data([1, 2, 3]))
        try store.deleteCapture(for: reading.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.captureURL(for: reading.id).path))
    }
}
