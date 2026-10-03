import Foundation

public final class ReadingStore {
    public let directory: URL
    public var audioDirectory: URL { directory.appendingPathComponent("Audio", isDirectory: true) }
    public var capturesDirectory: URL { directory.appendingPathComponent("Captures", isDirectory: true) }
    private var historyURL: URL { directory.appendingPathComponent("history.json") }

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: capturesDirectory, withIntermediateDirectories: true)
    }

    public func load() throws -> [Reading] {
        guard FileManager.default.fileExists(atPath: historyURL.path) else { return [] }
        return try JSONDecoder().decode([Reading].self, from: Data(contentsOf: historyURL))
    }

    public func save(_ readings: [Reading]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(readings).write(to: historyURL, options: .atomic)
    }

    /// Persist the retained list before deleting its unreferenced files.
    public func expire(_ readings: [Reading], after days: Int, now: Date = Date(), protecting activeID: UUID? = nil) throws -> [Reading] {
        guard days > 0 else { return readings }
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        let kept = readings.filter { $0.id == activeID || $0.createdAt >= cutoff }
        guard kept.count != readings.count else { return readings }
        try save(kept)
        let ids = Set(kept.map(\.id))
        for reading in readings where !ids.contains(reading.id) { try deleteCapture(for: reading.id) }
        try pruneAudio(keeping: kept)
        return kept
    }

    public func audioURL(for chunk: SpeechChunk) -> URL {
        audioDirectory.appendingPathComponent(chunk.key + ".wav")
    }

    public func hasAudio(for reading: Reading) -> Bool {
        reading.complete && !reading.chunks.isEmpty && reading.chunks.allSatisfy {
            FileManager.default.fileExists(atPath: audioURL(for: $0).path)
        }
    }

    public func captureURL(for id: UUID) -> URL {
        capturesDirectory.appendingPathComponent(id.uuidString + ".png")
    }

    public func saveCapture(_ png: Data, for id: UUID) throws {
        try png.write(to: captureURL(for: id), options: .atomic)
    }

    public func deleteCapture(for id: UUID) throws {
        let file = captureURL(for: id)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }

    public func pruneAudio(keeping readings: [Reading]) throws {
        let keys = Set(readings.flatMap(\.chunks).map(\.key))
        for file in try FileManager.default.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: nil) {
            if !keys.contains(file.deletingPathExtension().lastPathComponent) {
                try FileManager.default.removeItem(at: file)
            }
        }
    }
}
