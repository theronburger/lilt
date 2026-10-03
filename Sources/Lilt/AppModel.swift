import AppKit
import Combine
import AVFoundation
import UniformTypeIdentifiers
import LiltCore

@MainActor
final class AppModel: ObservableObject {
    static let voices = Voice.all.map { ($0.id, $0.name + " · " + $0.language) }

    static let sample = "Meet Lilt. A little space to listen and follow along.\n\nCapture a paragraph from anywhere on your screen, or paste something you want to read. Each word lights up as it is spoken. Click a word to start from there, and take things at your own pace."
    @Published var history: [Reading] = []
    @Published var current: Reading?
    @Published var captureImage: NSImage? { didSet { capturePalette = CapturePalette(image: captureImage) } }
    @Published var capturePalette = CapturePalette()
    @Published var showInDock = UserDefaults.standard.bool(forKey: "showInDock") {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            if !showInDock && !showInMenuBar { showInMenuBar = true }
            visibilityChanged?()
        }
    }
    @Published var showInMenuBar = UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar")
            if !showInMenuBar && !showInDock { showInDock = true }
            visibilityChanged?()
        }
    }
    var visibilityChanged: (() -> Void)?
    @Published var retentionDays = UserDefaults.standard.object(forKey: "retentionDays") as? Int ?? 7 {
        didSet { UserDefaults.standard.set(retentionDays, forKey: "retentionDays"); expireHistory() }
    }
    @Published var previewingVoice: String?
    private var previewPlayer: AVAudioPlayer?
    private var maintenanceTimer: Timer?
    private var previewTimer: Timer?
    @Published var status = "Ready when you are"
    @Published var error: String?
    @Published var isGenerating = false
    @Published var isCapturing = false
    @Published var needsScreenPermission = false
    @Published var voice: String { didSet { UserDefaults.standard.set(voice, forKey: "voice") } }
    @Published var fontSize: Double { didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") } }
    @Published var speed: Double {
        didSet { UserDefaults.standard.set(speed, forKey: "speed"); playback.speed = Float(speed) }
    }
    @Published var aiFiltering = UserDefaults.standard.bool(forKey: "aiFiltering") {
        didSet { UserDefaults.standard.set(aiFiltering, forKey: "aiFiltering") }
    }
    @Published var aiEndpoint = UserDefaults.standard.string(forKey: "aiEndpoint") ?? "https://api.openai.com/v1" {
        didSet { if aiEndpoint != oldValue { aiAPIKey = ""; keyNeedsUnlock = false }; UserDefaults.standard.set(aiEndpoint, forKey: "aiEndpoint") }
    }
    @Published var aiModel = UserDefaults.standard.string(forKey: "aiModel") ?? "gpt-6-luna" {
        didSet { UserDefaults.standard.set(aiModel, forKey: "aiModel") }
    }
    @Published var aiFormat = AITextFilter.Format(rawValue: UserDefaults.standard.string(forKey: "aiFormat") ?? "responses") ?? .responses {
        didSet { UserDefaults.standard.set(aiFormat.rawValue, forKey: "aiFormat") }
    }
    @Published var raceAIRequests = UserDefaults.standard.bool(forKey: "raceAIRequests") {
        didSet { UserDefaults.standard.set(raceAIRequests, forKey: "raceAIRequests") }
    }
    @Published var aiPronunciationHints = UserDefaults.standard.bool(forKey: "aiPronunciationHints") {
        didSet { UserDefaults.standard.set(aiPronunciationHints, forKey: "aiPronunciationHints") }
    }
    @Published var keyNeedsUnlock = false
    @Published var aiAPIKey = ""
    let playback = AudioPlayback()
    let speech = SpeechService()
    let store: ReadingStore
    var showReader: (() -> Void)?
    var capture: (() -> Void)?
    var openScreenPermissions: (() -> Void)?
    private var chunkIndex = 0
    private var wantsPlayback = false
    private var pendingCharacter: Int?
    private var lastSave = Date.distantPast
    private var subscriptions = Set<AnyCancellable>()

    init(directory: URL? = nil) throws {
        let defaults = UserDefaults.standard
        let savedVoice = defaults.string(forKey: "voice") ?? "af_heart"
        voice = Self.voices.contains(where: { $0.0 == savedVoice }) ? savedVoice : "af_heart"
        fontSize = defaults.object(forKey: "fontSize") == nil ? 25 : defaults.double(forKey: "fontSize")
        speed = defaults.object(forKey: "speed") == nil ? 1 : defaults.double(forKey: "speed")
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.supportFolder, isDirectory: true)
        store = try ReadingStore(directory: root)
        do { history = try store.load() }
        catch { self.error = "Could not load history: \(error.localizedDescription)" }
        playback.speed = Float(speed)
        playback.onBoundary = { [weak self] in self?.advance() }
        playback.onFailure = { [weak self] in self?.fail($0) }
        speech.onEvent = { [weak self] in self?.receive($0) }
        speech.onFailure = { [weak self] in self?.fail($0) }
        playback.$position.sink { [weak self] position in
            guard let self else { return }
            self.current?.position = position
            if Date().timeIntervalSince(self.lastSave) > 3 { self.saveCurrent() }
        }.store(in: &subscriptions)
        expireHistory()
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.expireHistory() }
        }
    }

    func readClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "There’s no text on the clipboard."; return
        }
        read(text, source: "Clipboard")
    }

    func apiKey() throws -> String {
        if !aiAPIKey.isEmpty { return aiAPIKey }
        do {
            let key = try FilterKeyStore.read(aiEndpoint) ?? ""
            keyNeedsUnlock = false
            return key
        } catch {
            keyNeedsUnlock = true
            throw error
        }
    }

    func read(_ text: String, source: String = "Pasted text") {
        let clean = ReadingText.normalize(text)
        guard !clean.isEmpty else { error = "There’s no text to read yet."; return }
        guard clean.count <= 50_000 else { error = "Try a shorter selection—up to 50,000 characters."; return }
        stopVoicePreview()
        saveCurrent()
        cancelGeneration()
        playback.reset()
        captureImage = nil
        current = Reading(text: clean, source: source, voice: voice)
        generate()
        showReader?()
    }

    func previewCapture(_ image: CGImage, pointSize: CGSize) {
        stopVoicePreview()
        saveCurrent()
        cancelGeneration()
        playback.reset()
        current = nil
        error = nil
        captureImage = NSImage(cgImage: image, size: pointSize)
        needsScreenPermission = false
        status = "Finding the words…"
        showReader?()
    }

    func filterCapture(_ recognized: CapturedText, image: CGImage) async throws -> FilteredCapture {
        if !aiFiltering {
            try Task.checkCancellation()
            status = "Reading with Vision…"
            return FilteredCapture(captured: recognized, hints: [])
        }
        status = "Filtering interface text…"
        let endpoint = aiEndpoint, selectedModel = aiModel
        let key = try apiKey()
        let minimumHeight = recognized.words.map { $0.bounds.height * CGFloat(image.height) }.filter { $0 > 0 }.min()
        let upload = try UploadImage.optimized(image, minimumWordHeight: minimumHeight)
        let useHints = aiPronunciationHints, british = voice.hasPrefix("b")
        let prompt = try FilterPrompt(directory: store.directory).load() + (useHints ? ParsedReading.instructions(british: british) : ""), format = aiFormat
        let result = try await RequestRace.first(attempts: raceAIRequests ? 3 : 1) {
            let response = try await AITextFilter.extract(png: upload.data, base: endpoint, model: selectedModel,
                key: key, prompt: prompt, format: format, mime: upload.mime, maxTokens: useHints ? 4096 : 2048)
            let result = try ParsedReading.decode(response, pronunciationHints: useHints, british: british)
            // Empty is a valid provider result for a capture containing only interface.
            guard result.text.isEmpty || recognized.aligning(result.text) != nil else { throw FilterError.alignment }
            return result
        }
        try Task.checkCancellation()
        guard !result.text.isEmpty else { throw FilterError.empty }
        guard let aligned = recognized.aligning(result.text) else { throw FilterError.alignment }
        return FilteredCapture(captured: aligned, hints: result.hints)
    }

    func readCapture(_ filtered: FilteredCapture, image: CGImage, pointSize: CGSize) throws {
        let recognized = filtered.captured
        guard !recognized.text.isEmpty, recognized.text.count <= 50_000 else {
            throw NSError(domain: "Lilt", code: 4, userInfo: [NSLocalizedDescriptionKey:
                recognized.text.isEmpty ? "No text was found. Try a larger, clearer selection." : "Try a shorter selection—up to 50,000 characters."])
        }
        var reading = Reading(text: recognized.text, source: "Screen capture", voice: voice)
        reading.pronunciationHints = filtered.hints.isEmpty ? nil : filtered.hints
        reading.snapshot = CaptureSnapshot(pointSize: pointSize, words: recognized.words)
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "Lilt", code: 5, userInfo: [NSLocalizedDescriptionKey: "Couldn’t save this capture."])
        }
        try store.saveCapture(png, for: reading.id)
        current = reading
        generate()
    }

    func open(_ reading: Reading) {
        stopVoicePreview()
        saveCurrent()
        cancelGeneration()
        playback.reset()
        current = reading
        if let snapshot = reading.snapshot, let image = NSImage(contentsOf: store.captureURL(for: reading.id)) {
            image.size = snapshot.pointSize
            captureImage = image
        } else { captureImage = nil }
        showReader?()
        if store.hasAudio(for: reading) {
            wantsPlayback = true
            status = "Click any word to jump there"
            seek(to: reading.position >= reading.duration - 0.1 ? 0 : reading.position, play: true)
        } else { generate() }
    }

    func togglePlayback() {
        stopVoicePreview()
        if playback.isPlaying || wantsPlayback {
            wantsPlayback = false
            playback.pause()
            pendingCharacter = nil
            saveCurrent()
        } else if let current, !current.chunks.isEmpty {
            wantsPlayback = true
            seek(to: playback.position >= current.duration - 0.05 ? 0 : playback.position, play: true)
        } else if !isGenerating { generate() }
        else { wantsPlayback = true }
    }

    func seek(to seconds: Double, play: Bool? = nil) {
        guard let current, let location = current.location(at: seconds) else { return }
        let shouldPlay = play ?? wantsPlayback
        pendingCharacter = nil
        chunkIndex = location.index
        let offset = current.chunks.prefix(chunkIndex).reduce(0) { $0 + $1.durationMs / 1000 }
        do {
            try playback.load(current.chunks[chunkIndex], url: store.audioURL(for: current.chunks[chunkIndex]),
                              offset: offset, at: location.seconds, play: shouldPlay)
            wantsPlayback = shouldPlay
        } catch { fail(error.localizedDescription) }
    }

    func seek(character: Int) {
        guard let current else { return }
        if let time = current.time(forCharacter: character) { seek(to: time, play: true) }
        else if isGenerating {
            pendingCharacter = character
            wantsPlayback = true
            playback.pause()
            status = "Preparing that part…"
        }
    }

    func previousSentence() {
        guard let current else { return }
        let nsText = current.text as NSString
        var starts = [0]
        let regex = try? NSRegularExpression(pattern: "[.!?][\\s]+|\n\n")
        for match in regex?.matches(in: current.text, range: NSRange(location: 0, length: nsText.length)) ?? [] {
            starts.append(NSMaxRange(match.range))
        }
        let times = starts.compactMap { start -> Double? in
            let word = current.chunks.flatMap(\.words).first { $0.charIndex >= start }
            return word.flatMap { current.time(forCharacter: $0.charIndex) }
        }
        let time = times.last { $0 < playback.position - 1.0 } ?? 0
        seek(to: time, play: true)
    }

    func closeReader() {
        wantsPlayback = false
        pendingCharacter = nil
        playback.pause()
        saveCurrent()
    }

    func delete(_ reading: Reading) {
        if current?.id == reading.id {
            cancelGeneration()
            playback.reset()
            current = nil
            captureImage = nil
        }
        history.removeAll { $0.id == reading.id }
        do {
            try store.save(history)
            try store.deleteCapture(for: reading.id)
            if !isGenerating { try store.pruneAudio(keeping: history) }
        } catch { self.error = "Could not remove the reading: \(error.localizedDescription)" }
    }

    func saveCurrent() {
        guard let current else { return }
        if let index = history.firstIndex(where: { $0.id == current.id }) { history[index] = current }
        else { history.insert(current, at: 0) }
        do { try store.save(history); lastSave = Date() }
        catch { self.error = "Could not save history: \(error.localizedDescription)" }
    }

    func shutdown() {
        maintenanceTimer?.invalidate(); stopVoicePreview()
        closeReader(); speech.stop()
    }

    func previewVoice(_ voice: Voice) {
        if previewingVoice == voice.id { stopVoicePreview(); return }
        closeReader(); stopVoicePreview()
        do {
            guard let url = voice.previewURL else { throw CocoaError(.fileNoSuchFile) }
            let player = try AVAudioPlayer(contentsOf: url)
            previewPlayer = player; previewingVoice = voice.id
            guard player.play() else { throw CocoaError(.fileReadCorruptFile) }
            previewTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if self.previewPlayer?.isPlaying != true { self.stopVoicePreview() }
                }
            }
        } catch { stopVoicePreview(); self.error = "Could not play the voice preview: \(error.localizedDescription)" }
    }

    func stopVoicePreview() {
        previewTimer?.invalidate(); previewTimer = nil
        previewPlayer?.stop(); previewPlayer = nil; previewingVoice = nil
    }

    func expireHistory() {
        guard !isGenerating else { return }
        do {
            history = try store.expire(history, after: retentionDays, protecting: current?.id)
        } catch {
            if let saved = try? store.load() { history = saved }
            self.error = "Could not clean up history: \(error.localizedDescription)" }
    }

    func export(_ reading: Reading, audio: Bool) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [audio ? .wav : .plainText]
        panel.nameFieldStringValue = String(reading.title.prefix(70)).replacingOccurrences(of: "/", with: "-") + (audio ? ".wav" : ".txt")
        panel.begin { [weak self] response in
            MainActor.assumeIsolated {
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    if audio { try AudioExport.write(reading, from: self.store, to: url) }
                    else { try reading.text.write(to: url, atomically: true, encoding: .utf8) }
                } catch { self.error = "Export failed: \(error.localizedDescription)" }
            }
        }
    }

    private func generate() {
        guard current != nil else { return }
        error = nil
        current?.chunks = []
        current?.complete = false
        current?.position = 0
        chunkIndex = 0
        pendingCharacter = nil
        wantsPlayback = true
        isGenerating = true
        status = "Preparing the voice…"
        saveCurrent()
        do { try speech.render(current!, directory: store.audioDirectory) }
        catch { fail(error.localizedDescription) }
    }

    private func receive(_ event: SpeechEvent) {
        guard event.id == current?.id.uuidString else { return }
        switch event.type {
        case "chunk":
            guard let chunk = event.chunk else { return }
            current?.chunks.append(chunk)
            if let pendingCharacter, let time = current?.time(forCharacter: pendingCharacter) {
                self.pendingCharacter = nil
                seek(to: time, play: true)
            } else if pendingCharacter == nil, wantsPlayback, !playback.isPlaying {
                seek(to: playback.position, play: true)
            }
            if pendingCharacter == nil { status = "Reading · preparing the rest…" }
            saveCurrent()
        case "complete":
            current?.complete = true
            isGenerating = false
            status = "Click any word to jump there"
            if pendingCharacter != nil { pendingCharacter = nil; wantsPlayback = false }
            saveCurrent()
        case "error": fail(event.message ?? "Speech generation failed.")
        default: break
        }
    }

    private func advance() {
        guard let current, wantsPlayback else { return }
        if chunkIndex + 1 < current.chunks.count {
            chunkIndex += 1
            let offset = current.chunks.prefix(chunkIndex).reduce(0) { $0 + $1.durationMs / 1000 }
            seek(to: offset, play: true)
        } else if isGenerating { status = "Preparing the next part…" }
        else { wantsPlayback = false; status = "All read. Take a breath."; saveCurrent() }
    }

    private func cancelGeneration() {
        if isGenerating { speech.stop() }
        isGenerating = false
        pendingCharacter = nil
        wantsPlayback = false
    }

    private func fail(_ message: String) {
        isGenerating = false
        wantsPlayback = false
        playback.pause()
        error = message
        status = "Couldn’t finish reading"
        saveCurrent()
    }
}
