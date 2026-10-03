import Foundation

struct FilterPrompt {
    let url: URL
    init(directory: URL) { url = directory.appendingPathComponent("reading-prompt.txt") }

    func load() throws -> String {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try AITextFilter.prompt.write(to: url, atomically: true, encoding: .utf8)
        }
        let text = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw FilterError.emptyPrompt }
        return text
    }
}
