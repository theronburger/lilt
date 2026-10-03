import XCTest
import AppKit
@testable import Lilt

final class AITextFilterTests: XCTestCase {
    func testEndpointAndRedirectBoundary() throws {
        XCTAssertEqual(try AITextFilter.endpoint("https://example.com/v1/").absoluteString, "https://example.com/v1/responses")
        XCTAssertEqual(try AITextFilter.endpoint("https://example.com").absoluteString, "https://example.com/responses")
        for invalid in ["http://example.com", "https://user:secret@example.com/v1", "https://example.com?key=bad"] {
            XCTAssertThrowsError(try AITextFilter.endpoint(invalid))
        }
    }

    func testStreamingGatewayCanFinishWithoutRepeatingItsText() throws {
        var stream = FilterStream()
        XCTAssertFalse(try stream.consume(Data(#"{"type":"response.output_text.delta","delta":"Keep this paragraph."}"#.utf8)))
        XCTAssertTrue(try stream.consume(Data(#"{"type":"response.completed","response":{"status":"completed","output":[]}}"#.utf8)))
        XCTAssertEqual(stream.text, "Keep this paragraph.")
        XCTAssertThrowsError(try stream.consume(Data(#"{"type":"response.incomplete"}"#.utf8)))
    }

    func testRefusalAndPartialResponsesAreNotSpoken() throws {
        XCTAssertThrowsError(try FilterStream.completedText(Data(#"{"status":"completed","output":[{"content":[{"type":"refusal","refusal":"No"}]}]}"#.utf8)))
        XCTAssertThrowsError(try FilterStream.completedText(Data(#"{"status":"incomplete","output":[]}"#.utf8)))
    }

    @MainActor func testRealOCRCanAlignBenchmarkExtractions() async throws {
        guard let path = ProcessInfo.processInfo.environment["LILT_FILTER_FIXTURES"] else { throw XCTSkip("Optional local screenshot corpus") }
        let root = URL(fileURLWithPath: path)
        let results = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("api-results-v2.json"))) as? [[String: Any]])
        for result in results where result["repeat"] as? Int == 1 {
            let id = try XCTUnwrap(result["case"] as? String)
            let text = try XCTUnwrap(result["text"] as? String)
            let image = try XCTUnwrap(NSImage(contentsOf: root.appendingPathComponent(id + ".png"))?.cgImage(forProposedRect: nil, context: nil, hints: nil))
            let ocr = try await TextRecognition.recognize(image)
            let aligned = try XCTUnwrap(ocr.aligning(text), "Unmatched screenshot: \(id)")
            XCTAssertEqual(aligned.text, text)
            XCTAssertTrue(aligned.words.allSatisfy { NSMaxRange($0.range) <= text.utf16.count })
        }
    }

    func testLiveGatewayMatchesKnownScreenshot() async throws {
        guard let key = ProcessInfo.processInfo.environment["LILT_TEST_API_KEY"],
              let endpoint = ProcessInfo.processInfo.environment["LILT_TEST_ENDPOINT"],
              let model = ProcessInfo.processInfo.environment["LILT_TEST_MODEL"],
              let path = ProcessInfo.processInfo.environment["LILT_FILTER_FIXTURES"] else { throw XCTSkip("Optional live gateway check") }
        let root = URL(fileURLWithPath: path)
        let png = try Data(contentsOf: root.appendingPathComponent("original.png"))
        let actual = try await AITextFilter.extract(png: png, base: endpoint, model: model, key: key)
        let fixtures = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("fixtures.json"))) as? [[String: Any]])
        let expected = try XCTUnwrap(fixtures.first { $0["id"] as? String == "original" }?["expected"] as? String)
        XCTAssertEqual(actual, expected)
    }
}
