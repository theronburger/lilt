import AppKit
import Vision
import LiltCore

enum TextRecognition {
    static func recognize(_ image: CGImage) async throws -> CapturedText {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            try VNImageRequestHandler(cgImage: image).perform([request])
            let lines = (request.results ?? []).sorted {
                if abs($0.boundingBox.midY - $1.boundingBox.midY) < min($0.boundingBox.height, $1.boundingBox.height) * 0.5 {
                    return $0.boundingBox.minX < $1.boundingBox.minX
                }
                return $0.boundingBox.midY > $1.boundingBox.midY
            }
            var text = ""
            var words: [CapturedWord] = []
            let tokenPattern = try NSRegularExpression(pattern: "\\S+")
            var previous: VNRecognizedTextObservation?
            for line in lines {
                guard let candidate = line.topCandidates(1).first else { continue }
                if let previous {
                    let gap = previous.boundingBox.minY - line.boundingBox.maxY
                    text += gap > max(previous.boundingBox.height, line.boundingBox.height) * 0.65 ? "\n\n" : " "
                }
                let tokens = tokenPattern.matches(in: candidate.string, range: NSRange(candidate.string.startIndex..., in: candidate.string))
                for (index, token) in tokens.enumerated() {
                    guard let range = Range(token.range, in: candidate.string) else { continue }
                    if index > 0 { text += " " }
                    let offset = text.utf16.count
                    let value = String(candidate.string[range])
                    text += value
                    if let box = try candidate.boundingBox(for: range)?.boundingBox {
                        // Vision uses a bottom-left origin; the screenshot canvas uses top-left.
                        let bounds = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
                            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
                        if !bounds.isEmpty && !bounds.isNull {
                            words.append(CapturedWord(charIndex: offset, charLength: value.utf16.count, bounds: bounds))
                        }
                    }
                }
                previous = line
            }
            return CapturedText(text: text, words: words)
        }.value
    }
}
