import XCTest
@testable import LiltCore

final class TextAlignmentTests: XCTestCase {
    func testFilteringKeepsOriginalBoxesAndRemapsUTF16() throws {
        let text = "Activity Hello 🌿 world Ran commands Hello again"
        let source = text as NSString
        let tokens = try NSRegularExpression(pattern: "\\S+").matches(in: text, range: NSRange(location: 0, length: source.length))
        let words = tokens.enumerated().map { index, token in
            CapturedWord(charIndex: token.range.location, charLength: token.range.length,
                bounds: CGRect(x: Double(index) / 10, y: 0, width: 0.05, height: 0.1))
        }
        let output = try XCTUnwrap(CapturedText(text: text, words: words).aligning("Hello 🌿 world\n\nHello again"))
        XCTAssertEqual(output.words.map(\.bounds), [words[1], words[3], words[6], words[7]].map(\.bounds))
        XCTAssertEqual(output.words.map(\.charIndex), [0, 9, 16, 22])
    }
    func testInventedOrRewrittenTextIsRejected() {
        let input = CapturedText(text: "Safe text", words: [CapturedWord(charIndex: 0, charLength: 4, bounds: .zero), CapturedWord(charIndex: 5, charLength: 4, bounds: .zero)])
        XCTAssertNil(input.aligning("Completely invented explanation"))
        XCTAssertEqual(input.aligning("")?.words.count, 0)
    }
}
