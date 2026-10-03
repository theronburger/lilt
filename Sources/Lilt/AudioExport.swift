import AVFoundation
import LiltCore

/// Join original PCM chunks without changing speed or introducing lossy encoding.
enum AudioExport {
    static func write(_ reading: Reading, from store: ReadingStore, to destination: URL) throws {
        guard store.hasAudio(for: reading), let first = reading.chunks.first else { throw CocoaError(.fileReadNoSuchFile) }
        let source = try AVAudioFile(forReading: store.audioURL(for: first))
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".lilt-export-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try join(reading, store: store, source: source, destination: temporary)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        } else { try FileManager.default.moveItem(at: temporary, to: destination) }
    }
    private static func join(_ reading: Reading, store: ReadingStore, source: AVAudioFile, destination: URL) throws {
        let output = try AVAudioFile(forWriting: destination, settings: source.fileFormat.settings,
                                     commonFormat: source.processingFormat.commonFormat, interleaved: source.processingFormat.isInterleaved)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: 8192) else { throw CocoaError(.fileWriteUnknown) }
        for chunk in reading.chunks {
            let input = try AVAudioFile(forReading: store.audioURL(for: chunk))
            guard input.processingFormat == source.processingFormat else { throw CocoaError(.fileReadCorruptFile) }
            while input.framePosition < input.length {
                try input.read(into: buffer)
                guard buffer.frameLength > 0 else { throw CocoaError(.fileReadCorruptFile) }
                try output.write(from: buffer)
            }
        }
    }
}
