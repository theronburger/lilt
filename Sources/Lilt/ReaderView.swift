import SwiftUI

struct ReaderView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var playback: AudioPlayback
    var openHistory: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "waveform").font(.title2).foregroundStyle(Color.accentColor)
                Text(AppIdentity.name).font(.title3.weight(.semibold))
                Spacer()
                if model.isGenerating { ProgressView().controlSize(.small) }
                Text(model.current?.source ?? "Your reading space").font(.caption).foregroundStyle(.secondary)
                Button(action: openHistory) { Image(systemName: "clock.arrow.circlepath") }
                    .buttonStyle(.borderless).help("Open history")
                Menu {
                    Button("Copy text") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(model.current?.text ?? "", forType: .string)
                    }
                    Button("Larger text") { model.fontSize = min(38, model.fontSize + 2) }
                    Button("Smaller text") { model.fontSize = max(17, model.fontSize - 2) }
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize()
            }
            .padding(.horizontal, 26).padding(.top, 14).padding(.bottom, 18)
            Divider()
            if let current = model.current {
                ReadingTextView(text: current.text, fontSize: model.fontSize,
                                activeRange: playback.activeRange, onWord: model.seek(character:))
            } else {
                ContentUnavailableView("A little space to listen", systemImage: "waveform",
                                       description: Text("Capture or paste some text to begin."))
            }
            if let error = model.error {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.circle")
                    Text(error).textSelection(.enabled)
                    Spacer()
                    Button("Dismiss") { model.error = nil }
                }
                .font(.callout).foregroundStyle(.red).padding(18)
                .background(Color.red.opacity(0.05))
            }
            Divider()
            VStack(spacing: 14) {
                HStack {
                    Text(time(playback.position)).monospacedDigit().frame(width: 38, alignment: .leading)
                    Slider(value: Binding(get: { min(playback.position, duration) }, set: { model.seek(to: $0) }),
                           in: 0...max(duration, 0.01))
                        .disabled(duration == 0).accessibilityLabel("Reading progress")
                    Text(model.isGenerating ? "…" : time(duration)).monospacedDigit().frame(width: 38, alignment: .trailing)
                }.font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 22) {
                        Button(action: model.previousSentence) { Image(systemName: "backward.end.fill") }
                            .buttonStyle(.borderless).help("Previous sentence").accessibilityLabel("Previous sentence")
                        Button(action: model.togglePlayback) {
                            Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3).frame(width: 42, height: 36)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.space, modifiers: [])
                        .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
                    }
                    Menu {
                        ForEach([0.75, 1, 1.15, 1.25, 1.5, 1.75, 2], id: \.self) { rate in
                            Button("\(rate.formatted())×") { model.speed = rate }
                        }
                    } label: { Text("\(model.speed.formatted())×").monospacedDigit() }
                    .fixedSize().frame(maxWidth: .infinity, alignment: .trailing)
                    .help("Playback speed")
                }
            }.padding(.horizontal, 26).padding(.vertical, 20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 520, minHeight: 360)
    }

    private var duration: Double { model.current?.duration ?? 0 }
    private func time(_ value: Double) -> String { String(format: "%d:%02d", Int(value) / 60, Int(value) % 60) }
}
