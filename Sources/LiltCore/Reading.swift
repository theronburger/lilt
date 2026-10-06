import Foundation

public struct PronunciationHint: Codable, Equatable, Sendable {
    public var charIndex: Int
    public var charLength: Int
    public var phonemes: String

    public init(charIndex: Int, charLength: Int, phonemes: String) {
        self.charIndex = charIndex; self.charLength = charLength; self.phonemes = phonemes
    }
}

public struct WordTiming: Codable, Equatable, Sendable {
    public var charIndex: Int
    public var charLength: Int
    public var startMs: Double
    public var endMs: Double

    public init(charIndex: Int, charLength: Int, startMs: Double, endMs: Double) {
        self.charIndex = charIndex
        self.charLength = charLength
        self.startMs = startMs
        self.endMs = endMs
    }

    public var range: NSRange { NSRange(location: charIndex, length: charLength) }
}

public struct SpeechChunk: Codable, Sendable {
    public var key: String
    public var durationMs: Double
    public var words: [WordTiming]
    public var charOffset: Int

    public init(key: String, durationMs: Double, words: [WordTiming], charOffset: Int) {
        self.key = key
        self.durationMs = durationMs
        self.words = words
        self.charOffset = charOffset
    }

    public func activeWord(at seconds: Double) -> WordTiming? {
        words.first { $0.startMs <= seconds * 1000 && seconds * 1000 < $0.endMs }
    }
}

public struct Reading: Codable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var text: String
    public var source: String
    public var voice: String
    public var chunks: [SpeechChunk]
    public var complete: Bool
    public var position: Double
    public var customTitle: String?
    public var pronunciationHints: [PronunciationHint]?
    public var snapshot: CaptureSnapshot?

    public init(text: String, source: String, voice: String) {
        id = UUID()
        createdAt = Date()
        self.text = text
        self.source = source
        self.voice = voice
        chunks = []
        complete = false
        position = 0
    }

    public var title: String { customTitle ?? String(text.split(whereSeparator: \.isWhitespace).prefix(10).joined(separator: " ")) }
    public var duration: Double { chunks.reduce(0) { $0 + $1.durationMs / 1000 } }
    public var wordCount: Int { text.split(whereSeparator: \.isWhitespace).count }

    public func location(at seconds: Double) -> (index: Int, seconds: Double)? {
        guard !chunks.isEmpty else { return nil }
        let position = max(0, seconds)
        var offset = 0.0
        for (index, chunk) in chunks.enumerated() {
            let duration = chunk.durationMs / 1000
            let end = offset + duration
            // Match the accumulated playback clock; repeated subtraction can
            // round an exact boundary back into the preceding chunk.
            if position < end || index == chunks.count - 1 {
                return (index, min(max(0, position - offset), duration))
            }
            offset = end
        }
        return nil
    }

    public func time(forCharacter character: Int) -> Double? {
        var offset = 0.0
        for chunk in chunks {
            if let word = chunk.words.first(where: { NSLocationInRange(character, $0.range) }) {
                return offset + word.startMs / 1000
            }
            offset += chunk.durationMs / 1000
        }
        return nil
    }
}

public enum ReadingText {
    public static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
