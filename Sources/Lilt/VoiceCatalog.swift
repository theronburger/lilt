import Foundation

struct Voice: Codable, Identifiable {
    let id: String
    let name: String
    let language: String
    static let all: [Voice] = {
        let resource = Bundle.main.resourceURL?.appendingPathComponent("Speech/voices.json")
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Speech/voices.json")
        guard let data = try? Data(contentsOf: resource.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ?? source),
              let voices = try? JSONDecoder().decode([Voice].self, from: data) else { return [] }
        return voices
    }()
    var previewURL: URL? { Bundle.main.resourceURL?.appendingPathComponent("Voices/\(id).wav") }
}
