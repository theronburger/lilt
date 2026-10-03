import Foundation
import LiltCore

struct ParsedReading {
    let text: String
    let hints: [PronunciationHint]

    static func decode(_ response: String, pronunciationHints: Bool, british: Bool) throws -> Self {
        guard pronunciationHints else { return Self(text: response, hints: []) }
        var json = response.trimmingCharacters(in: .whitespacesAndNewlines)
        // Some compatible providers wrap JSON in a Markdown fence.
        if json.hasPrefix("```"), let newline = json.firstIndex(of: "\n"), json.hasSuffix("```") {
            json = String(json[json.index(after: newline)...].dropLast(3))
        }
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = object["text"] as? String else { throw FilterError.pronunciationFormat }
        let items = object["pronunciations"] as? [[String: Any]] ?? []
        let alphabet = Set("AIWYbdfhijklmnpstuvwzðŋɑɔəɛɜɡɪɹʃʊʌʒʤʧˈˌθᵊ " + (british ? "Qaɒː" : "Oæɾᵻ"))
        let spoken = Set("AIWYaeiouæɑɔəɛɜɪʊʌᵊᵻɒOQ")
        var hints: [PronunciationHint] = []
        for item in items.prefix(32) {
            guard let word = item["word"] as? String, !word.isEmpty, word.count <= 64,
                  word.range(of: #"^[\p{L}\p{N}][\p{L}\p{N}'’\-]*$"#, options: .regularExpression) != nil,
                  let phones = item["phonemes"] as? String, !phones.isEmpty, phones.count <= 64,
                  phones.allSatisfy({ alphabet.contains($0) }), phones.contains(where: { spoken.contains($0) }) else { continue }
            let occurrence = item["occurrence"] as? Int ?? 1
            guard occurrence > 0, occurrence <= 500 else { continue }
            let pattern = #"(?<![\p{L}\p{N}_])"# + NSRegularExpression.escapedPattern(for: word) + #"(?![\p{L}\p{N}_])"#
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
            guard occurrence <= matches.count else { continue }
            let range = matches[occurrence - 1].range
            guard !hints.contains(where: { $0.charIndex == range.location }) else { continue }
            hints.append(PronunciationHint(charIndex: range.location, charLength: range.length, phonemes: phones))
        }
        return Self(text: text, hints: hints.sorted { $0.charIndex < $1.charIndex })
    }

    static func instructions(british: Bool) -> String {
        """

        OUTPUT FORMAT OVERRIDE: Return a JSON object only, with exactly these fields:
        {"text":"the faithful extracted reading text", "pronunciations":[{"word":"Kokoro","occurrence":1,"phonemes":"\(british ? "kˈQkəɹQ" : "kˈOkəɹO")"}]}
        Do not put annotations or phonetic spellings inside text. Keep the text exactly as requested above.
        Pronunciations are optional hints for English speech. Supply at most 32, only for unusual names, acronyms or context-dependent pronunciations (such as past-tense read). Leave ordinary words to the speech engine. If unsure, omit the hint. No rewriting, expansions or emotional directions. An empty list is fine.
        Each word must be ONE exact written word in text, without surrounding punctuation. occurrence is its 1-based occurrence in text, matching case. Use the \(british ? "British" : "American") English accent of the selected voice.
        Use Kokoro/Misaki phonemes, NOT arbitrary IPA. Shared symbols: AIWYbdfhijklmnpstuvwzðŋɑɔəɛɜɡɪɹʃʊʌʒʤʧˈˌθᵊ. Accent symbols: \(british ? "Qaɒː" : "Oæɾᵻ"). Spaces may separate spoken letters in acronyms. A=eɪ, I=aɪ, W=aʊ, Y=ɔɪ, \(british ? "Q=əʊ" : "O=oʊ"). Use ɡ for g, ɹ for r, ʤ for dʒ and ʧ for tʃ. ˈ marks primary stress. Maximum 64 symbols per hint.
        If there is no reading content, return {"text":"","pronunciations":[]}.
        """
    }
}

struct FilteredCapture {
    let captured: CapturedText
    let hints: [PronunciationHint]
}
