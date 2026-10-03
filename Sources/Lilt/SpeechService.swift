import Foundation
import LiltCore

struct SpeechEvent: Decodable {
    var id: String
    var type: String
    var chunk: SpeechChunk?
    var message: String?
}

@MainActor
final class SpeechService {
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var errorLog: FileHandle?
    private var buffer = Data()
    var onEvent: ((SpeechEvent) -> Void)?
    var onFailure: ((String) -> Void)?

    func render(_ reading: Reading, directory: URL) throws {
        if process?.isRunning != true { try start(directory: directory) }
        var request: [String: Any] = ["id": reading.id.uuidString, "text": reading.text, "voice": reading.voice]
        if let hints = reading.pronunciationHints, !hints.isEmpty {
            request["pronunciations"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(hints))
        }
        var data = try JSONSerialization.data(withJSONObject: request)
        data.append(0x0A)
        try input?.write(contentsOf: data)
    }

    func stop() {
        output?.readabilityHandler = nil
        process?.terminationHandler = nil
        if process?.isRunning == true { process?.terminate() }
        try? input?.close()
        try? output?.close()
        try? errorLog?.close()
        process = nil
        input = nil
        output = nil
        errorLog = nil
        buffer.removeAll()
    }

    private func start(directory: URL) throws {
        guard let resources = Bundle.main.resourceURL,
              let config = try? Data(contentsOf: resources.appendingPathComponent("runtime.json")),
              let runtime = try JSONSerialization.jsonObject(with: config) as? [String: String],
              let configuredPython = runtime["python"] else {
            throw NSError(domain: "Lilt", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "The local speech runtime is missing. Reinstall Lilt to restore it."])
        }
        let python = configuredPython.hasPrefix("/") ? URL(fileURLWithPath: configuredPython) : resources.appendingPathComponent(configuredPython)
        guard FileManager.default.isExecutableFile(atPath: python.path) else {
            throw NSError(domain: "Lilt", code: 1, userInfo: [NSLocalizedDescriptionKey: "The local speech runtime is missing. Reinstall Lilt to restore it."])
        }
        let worker = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        worker.executableURL = python
        worker.arguments = ["-I", "-B", "-u", resources.appendingPathComponent("Speech/worker.py").path, directory.path]
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        environment["HF_HUB_DISABLE_PROGRESS_BARS"] = "1"
        environment["TOKENIZERS_PARALLELISM"] = "false"
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        if runtime["model"] != nil {
            environment["LILT_MODEL_DIRECTORY"] = resources.appendingPathComponent(runtime["model"]!).path
            environment["HF_HUB_OFFLINE"] = "1"
            environment["TRANSFORMERS_OFFLINE"] = "1"
        }
        worker.environment = environment
        worker.standardInput = stdin
        worker.standardOutput = stdout
        let logURL = directory.deletingLastPathComponent().appendingPathComponent("speech.log")
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        let log = try FileHandle(forWritingTo: logURL)
        try log.seekToEnd()
        worker.standardError = log
        errorLog = log
        stdout.fileHandleForReading.readabilityHandler = { [weak self, weak worker] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            Task { @MainActor in
                guard let self, self.process === worker else { return }
                self.receive(data)
            }
        }
        worker.terminationHandler = { [weak self] worker in
            Task { @MainActor in
                guard let self, self.process === worker else { return }
                self.output?.readabilityHandler = nil
                self.process = nil
                self.onFailure?("The speech helper stopped (\(worker.terminationStatus)). Try reading again. Details are in speech.log.")
            }
        }
        process = worker
        input = stdin.fileHandleForWriting
        output = stdout.fileHandleForReading
        try worker.run()
    }

    private func receive(_ data: Data) {
        buffer.append(data)
        while let end = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<end]
            buffer.removeSubrange(...end)
            do { onEvent?(try JSONDecoder().decode(SpeechEvent.self, from: line)) }
            catch { onFailure?("Could not read the speech helper’s response: \(error.localizedDescription)") }
        }
    }
}
