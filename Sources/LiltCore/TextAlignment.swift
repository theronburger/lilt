import Foundation

extension CapturedText {
    public func aligning(_ extracted: String) -> CapturedText? {
        let regex = try! NSRegularExpression(pattern: "\\S+")
        let output = extracted as NSString
        let ranges = regex.matches(in: extracted, range: NSRange(location: 0, length: output.length)).map(\.range)
        guard !ranges.isEmpty else { return CapturedText(text: "", words: []) }
        guard ranges.count * words.count <= 4_000_000 else { return nil }
        func normalized(_ value: String) -> String {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
        }
        let original = text as NSString
        let source = words.map { normalized(original.substring(with: $0.range)) }
        let target = ranges.map { normalized(output.substring(with: $0)) }
        let columns = source.count + 1
        var directions = [UInt8](repeating: 0, count: (target.count + 1) * columns)
        var previous = [Int](repeating: 0, count: columns)
        for i in 1...target.count {
            var current = [Int](repeating: 0, count: columns)
            if !source.isEmpty {
                for j in 1...source.count {
                    if !target[i - 1].isEmpty && target[i - 1] == source[j - 1] {
                        current[j] = previous[j - 1] + 1
                        directions[i * columns + j] = 1
                    } else if previous[j] >= current[j - 1] {
                        current[j] = previous[j]
                        directions[i * columns + j] = 2
                    } else {
                        current[j] = current[j - 1]
                        directions[i * columns + j] = 3
                    }
                }
            }
            previous = current
        }
        var i = target.count, j = source.count
        var aligned: [CapturedWord] = []
        while i > 0 && j > 0 {
            switch directions[i * columns + j] {
            case 1:
                aligned.append(CapturedWord(charIndex: ranges[i - 1].location, charLength: ranges[i - 1].length, bounds: words[j - 1].bounds))
                i -= 1; j -= 1
            case 2: i -= 1
            default: j -= 1
            }
        }
        let meaningful = target.filter { !$0.isEmpty }.count
        guard meaningful > 0, Double(aligned.count) / Double(meaningful) >= 0.95 else { return nil }
        return CapturedText(text: extracted, words: aligned.reversed())
    }
}
