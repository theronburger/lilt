import SwiftUI
import LiltCore

struct CaptureReaderView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var playback: AudioPlayback
    var close: () -> Void = {}
    @State private var hovered = false

    var body: some View {
        Group {
            if let image = model.captureImage {
                CapturedTextView(image: image, text: model.current?.text ?? "",
                                 words: model.current?.snapshot?.words ?? [],
                                 activeRange: playback.activeRange, onWord: model.seek(character:))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .top) {
                        if let error = model.error {
                            Text(error).font(.callout).padding(12)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                .padding(8).textSelection(.enabled)
                        }
                    }
            }
        }
        .background(Color(nsColor: model.capturePalette.background))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            Button(action: close) { Image(systemName: "xmark").padding(6) }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .background(.regularMaterial, in: Circle())
                .help("Close reader").accessibilityLabel("Close reader")
                .keyboardShortcut(.cancelAction)
                .padding(8)
                .opacity(hovered || NSWorkspace.shared.isVoiceOverEnabled ? 1 : 0)
        }
        .onHover { hovered = $0 }
        .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 3)
        .padding(CaptureLayout.shadowInset)
    }
}

struct CaptureControlsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var playback: AudioPlayback

    var body: some View {
        HStack {
            Button(action: model.togglePlayback) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
            }
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
            .disabled(model.current == nil)
            if model.isCapturing || (model.isGenerating && duration == 0) {
                ProgressView().controlSize(.small)
                Text(model.status).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Slider(value: Binding(get: { min(playback.position, duration) }, set: { model.seek(to: $0) }),
                       in: 0...max(duration, 0.01))
                    .disabled(duration == 0)
                    .focusEffectDisabled()
                    .accessibilityLabel("Reading progress")
            }
            Menu {
                ForEach([0.75, 1, 1.15, 1.25, 1.5, 1.75, 2], id: \.self) { rate in
                    Button("\(rate.formatted())×") { model.speed = rate }
                }
            } label: { Text("\(model.speed.formatted())×").monospacedDigit() }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Playback speed")
            .accessibilityLabel("Playback speed")
        }
        .buttonStyle(.borderless)
        .controlSize(.regular)
        .padding(.horizontal, 12)
        .frame(height: CaptureLayout.controlsHeight)
    }

    private var duration: Double { model.current?.duration ?? 0 }
}
