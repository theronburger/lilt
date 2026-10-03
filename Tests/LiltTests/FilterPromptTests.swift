import XCTest
@testable import Lilt

final class FilterPromptTests: XCTestCase {
    func testCreatesDefaultAndReadsUserEditsWithoutOverwriting() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let prompt = FilterPrompt(directory: directory)
        XCTAssertEqual(try prompt.load(), AITextFilter.prompt)
        try "Keep only prose.".write(to: prompt.url, atomically: true, encoding: .utf8)
        XCTAssertEqual(try prompt.load(), "Keep only prose.")
        try "  \n".write(to: prompt.url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try prompt.load())
    }

    func testMissingKeyAndModelHaveSpecificErrors() async throws {
        do {
            _ = try await AITextFilter.extract(png: Data(), base: "https://example.com", model: "model", key: "")
            XCTFail("Expected missing key")
        } catch FilterError.missingKey {} catch { XCTFail("Unexpected error: \(error)") }
        do {
            _ = try await AITextFilter.extract(png: Data(), base: "https://example.com", model: "", key: "test")
            XCTFail("Expected missing model")
        } catch FilterError.missingModel {} catch { XCTFail("Unexpected error: \(error)") }
    }
}
