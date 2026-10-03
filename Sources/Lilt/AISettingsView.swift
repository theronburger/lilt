import SwiftUI
import AppKit

struct AISettingsView: View {
    @ObservedObject var model: AppModel
    @State private var hasSavedKey = false
    @State private var editingKey = false
    @State private var draftKey = ""
    @State private var rememberKey = true
    @State private var feedback: String?
    @State private var keyError: String?
    @State private var testing = false
    @State private var removingKey = false

    var body: some View {
        Section("AI text filtering") {
            Toggle("Filter interface text with AI", isOn: $model.aiFiltering)
            Text("Sends selected screenshots to your AI provider. When off, reading stays on this Mac.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("AI pronunciation hints", isOn: $model.aiPronunciationHints)
                .disabled(!model.aiFiltering)
            Text("Experimental. Uses the same request to suggest pronunciations for names, acronyms and ambiguous words. Applies to new captures.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("API format", selection: $model.aiFormat) {
                Text("Responses").tag(AITextFilter.Format.responses)
                Text("Chat Completions").tag(AITextFilter.Format.chat)
            }.disabled(testing)
            TextField("API base URL", text: $model.aiEndpoint)
                .disabled(testing)
            TextField("Model", text: $model.aiModel).disabled(testing)
            LabeledContent("API key") {
                Text(!model.aiAPIKey.isEmpty ? "•••••••• · This session" : hasSavedKey ? (model.keyNeedsUnlock ? "Saved key · Locked" : "•••••••• · Saved in Keychain") : "Not set")
                    .foregroundStyle(.secondary)
                Button(hasSavedKey || !model.aiAPIKey.isEmpty ? "Change…" : "Add key…") {
                    draftKey = ""; keyError = nil; editingKey = true
                }.disabled(testing)
                if hasSavedKey || !model.aiAPIKey.isEmpty {
                    if model.keyNeedsUnlock { Button("Unlock saved key") {
                        do {
                            guard try FilterKeyStore.read(model.aiEndpoint, allowInteraction: true) != nil else { throw FilterError.missingKey }
                            model.keyNeedsUnlock = false
                            feedback = "Key unlocked for this session."
                        } catch { feedback = error.localizedDescription }
                    }.disabled(testing || !model.aiAPIKey.isEmpty) }
                    Button("Remove…", role: .destructive) { removingKey = true }.disabled(testing)
                }
            }
            HStack {
                Button(testing ? "Testing…" : "Test connection") { Task { await testConnection() } }
                    .disabled(testing)
                if testing { ProgressView().controlSize(.small) }
            }
            if let feedback { Text(feedback).font(.caption).textSelection(.enabled) }
            Toggle("Race three requests", isOn: $model.raceAIRequests)
            Text("Use the first complete response that matches the screenshot. Cancels the others. Can reduce latency spikes, but may cost up to three times as much.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Edit reading prompt…") {
                do {
                    let prompt = FilterPrompt(directory: model.store.directory)
                    _ = try prompt.load()
                    NSWorkspace.shared.open(prompt.url)
                } catch { feedback = error.localizedDescription }
            }
        }
        .onAppear { refreshKeyState() }
        .onChange(of: model.aiEndpoint) { _, _ in refreshKeyState(); feedback = nil }
        .onChange(of: model.aiModel) { _, _ in feedback = nil }
        .onChange(of: model.aiFormat) { _, _ in feedback = nil }
        .sheet(isPresented: $editingKey, onDismiss: { draftKey = "" }) {
            VStack(alignment: .leading, spacing: 16) {
                Text(hasSavedKey ? "Change API key" : "Add API key").font(.headline)
                Text(model.aiEndpoint).font(.caption).textSelection(.enabled)
                SecureField("API key", text: $draftKey)
                Toggle("Save securely in Keychain", isOn: $rememberKey)
                Text(rememberKey ? "Available after you restart Lilt." : "Kept only until you quit Lilt.")
                    .font(.caption).foregroundStyle(.secondary)
                if let keyError { Text(keyError).font(.caption).foregroundStyle(.red) }
                HStack {
                    Spacer()
                    Button("Cancel") { editingKey = false }.keyboardShortcut(.cancelAction)
                    Button("Save") { saveKey() }.keyboardShortcut(.defaultAction)
                        .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(24).frame(width: 420)
        }
        .confirmationDialog("Remove the API key for this endpoint?", isPresented: $removingKey) {
            Button("Remove key", role: .destructive) {
                do {
                    try FilterKeyStore.remove(model.aiEndpoint)
                    model.aiAPIKey = ""; refreshKeyState(); feedback = "API key removed."
                } catch { feedback = error.localizedDescription }
            }
        }
    }

    private func refreshKeyState() {
        let state = FilterKeyStore.state(model.aiEndpoint)
        hasSavedKey = state != .missing
        if state == .locked { model.keyNeedsUnlock = true }
    }

    private func saveKey() {
        do {
            _ = try AITextFilter.endpoint(model.aiEndpoint)
            let key = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if rememberKey {
                try FilterKeyStore.save(key, endpoint: model.aiEndpoint)
                model.aiAPIKey = ""
            } else {
                // Replacing a saved key with a session key must not resurrect the old key on restart.
                try FilterKeyStore.remove(model.aiEndpoint)
                model.aiAPIKey = key
            }
            model.keyNeedsUnlock = false
            refreshKeyState(); feedback = nil; editingKey = false; draftKey = ""
        } catch { keyError = error.localizedDescription }
    }

    @MainActor private func testConnection() async {
        testing = true; feedback = nil
        defer { testing = false }
        let endpoint = model.aiEndpoint, selectedModel = model.aiModel
        do {
            let key = try model.apiKey()
            let sample = "Lilt keeps the captured text in place while it reads aloud. Each word lights up as it is spoken, so you can follow along without losing your place. Click a word to continue from there.\n\nThe playback controls appear below the image when you move your pointer over it. Move away and the controls disappear. You can pause, change the speed, or close the reader at any time.\n\nYour reading history stays on this Mac. Local reading works without an internet connection. When AI filtering is enabled, the selected screenshot is sent to your chosen provider to remove interface clutter."
            let image = NSImage(size: NSSize(width: 900, height: 520))
            image.lockFocus()
            NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 900, height: 520).fill()
            (sample as NSString).draw(in: NSRect(x: 24, y: 24, width: 852, height: 472), withAttributes: [.font: NSFont.systemFont(ofSize: 24), .foregroundColor: NSColor.black])
            image.unlockFocus()
            guard let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { throw FilterError.incomplete }
            let start = Date()
            let useHints = model.aiPronunciationHints, british = model.voice.hasPrefix("b")
            let prompt = try FilterPrompt(directory: model.store.directory).load() + (useHints ? ParsedReading.instructions(british: british) : "")
            let response = try await AITextFilter.extract(png: png, base: endpoint, model: selectedModel, key: key,
                prompt: prompt, format: model.aiFormat, maxTokens: useHints ? 4096 : 2048)
            let result = try ParsedReading.decode(response, pronunciationHints: useHints, british: british)
            let normalize: (String) -> String = { $0.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
            guard normalize(result.text) == normalize(sample) else { throw FilterError.incomplete }
            feedback = "Sample capture passed · \(String(format: "%.1f", Date().timeIntervalSince(start))) seconds"
        } catch { feedback = error.localizedDescription }
    }
}
