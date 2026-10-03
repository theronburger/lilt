import XCTest
import LiltCore
@testable import Lilt

final class PronunciationParserTests: XCTestCase {
    func testContextDependentHintsKeepOriginalUTF16Spans() throws {
        let response = #"{"text":"👋 I read it yesterday. I read every day.","pronunciations":[{"word":"read","occurrence":1,"phonemes":"ɹˈɛd"},{"word":"read","occurrence":2,"phonemes":"ɹˈid"}]}"#
        let result = try ParsedReading.decode(response, pronunciationHints: true, british: false)
        XCTAssertEqual(result.hints.count, 2)
        XCTAssertEqual(result.hints.map(\.charIndex), [5, 26])
        for hint in result.hints {
            XCTAssertEqual((result.text as NSString).substring(with: NSRange(location: hint.charIndex, length: hint.charLength)), "read")
        }
        var reading = Reading(text: result.text, source: "Test", voice: "af_heart")
        reading.pronunciationHints = result.hints
        XCTAssertEqual(try JSONDecoder().decode(Reading.self, from: JSONEncoder().encode(reading)).pronunciationHints, result.hints)
    }

    func testBadHintsAreIgnoredWithoutChangingTheReading() throws {
        let response = #"{"text":"Kokoro sees arrows →.","pronunciations":[{"word":"Kokoro","phonemes":"kˈOkəɹO"},{"word":"Kokoro","phonemes":"garbage"},{"word":"sees","phonemes":"ˈ"},{"word":"arrows","occurrence":9,"phonemes":"ˈæɹOz"},{"word":"→","phonemes":"ɹIt"},{"word":"missing","phonemes":"mˈɪsɪŋ"}]}"#
        let result = try ParsedReading.decode(response, pronunciationHints: true, british: false)
        XCTAssertEqual(result.text, "Kokoro sees arrows →.")
        XCTAssertEqual(result.hints, [PronunciationHint(charIndex: 0, charLength: 6, phonemes: "kˈOkəɹO")])
        XCTAssertTrue(try ParsedReading.decode(response, pronunciationHints: true, british: true).hints.isEmpty)
    }

    func testFormatErrorsAndPlainMode() throws {
        XCTAssertThrowsError(try ParsedReading.decode("Just text", pronunciationHints: true, british: false))
        XCTAssertEqual(try ParsedReading.decode("Just text", pronunciationHints: false, british: false).text, "Just text")
        let empty = try ParsedReading.decode("```json\n{\"text\":\"\",\"pronunciations\":[]}\n```", pronunciationHints: true, british: false)
        XCTAssertEqual(empty.text, "")
        XCTAssertTrue(empty.hints.isEmpty)
    }
}
