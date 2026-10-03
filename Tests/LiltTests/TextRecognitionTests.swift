import XCTest
import AppKit
@testable import Lilt

final class TextRecognitionTests: XCTestCase {
    @MainActor func testVisionRecognizesRealRenderedText() async throws {
        let image = NSImage(size: NSSize(width: 1100, height: 220))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 1100, height: 220).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 40), .foregroundColor: NSColor.black
        ]
        ("A little space to listen." as NSString).draw(at: NSPoint(x: 35, y: 135), withAttributes: attributes)
        ("Every word finds its rhythm." as NSString).draw(at: NSPoint(x: 35, y: 65), withAttributes: attributes)
        image.unlockFocus()
        let bitmap = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let result = try await TextRecognition.recognize(bitmap)
        let text = result.text
        XCTAssertTrue(text.contains("A little space to listen."), text)
        XCTAssertTrue(text.contains("Every word finds its rhythm."), text)
        XCTAssertLessThan(try XCTUnwrap(text.range(of: "A little")?.lowerBound), try XCTUnwrap(text.range(of: "Every word")?.lowerBound))
        let little = try XCTUnwrap(result.words.first { (text as NSString).substring(with: $0.range) == "little" })
        let every = try XCTUnwrap(result.words.first { (text as NSString).substring(with: $0.range) == "Every" })
        XCTAssertLessThan(little.bounds.minY, every.bounds.minY)
        XCTAssertGreaterThan(little.bounds.minX, every.bounds.minX)
        XCTAssertLessThan(little.bounds.width, 0.25, "A word must not get the whole line's box")
        for word in result.words {
            XCTAssertTrue(CGRect(x: 0, y: 0, width: 1, height: 1).contains(word.bounds))
            XCTAssertFalse((text as NSString).substring(with: word.range).isEmpty)
        }

        // Local reading must preserve Vision's exact text/boxes without any model runtime or provider.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let originalPreference = UserDefaults.standard.object(forKey: "aiFiltering")
        let model = try AppModel(directory: directory)
        defer {
            model.shutdown()
            if let originalPreference { UserDefaults.standard.set(originalPreference, forKey: "aiFiltering") }
            else { UserDefaults.standard.removeObject(forKey: "aiFiltering") }
            try? FileManager.default.removeItem(at: directory)
        }
        model.aiFiltering = false
        let local = try await model.filterCapture(result, image: bitmap)
        XCTAssertEqual(local.captured.text, result.text)
        XCTAssertEqual(local.captured.words, result.words)
        XCTAssertTrue(local.hints.isEmpty)
    }
}
