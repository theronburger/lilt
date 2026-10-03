import AVFoundation
import Combine
import LiltCore

@MainActor
final class AudioPlayback: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var position = 0.0
    @Published private(set) var activeRange: NSRange?
    @Published var speed: Float = 1 { didSet { player?.rate = speed } }
    var onBoundary: (() -> Void)?
    var onFailure: ((String) -> Void)?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var chunk: SpeechChunk?
    private var offset = 0.0

    func load(_ chunk: SpeechChunk, url: URL, offset: Double, at seconds: Double = 0, play: Bool) throws {
        stop()
        self.chunk = chunk
        self.offset = offset
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.enableRate = true
        player.rate = speed
        player.prepareToPlay()
        player.currentTime = seconds
        self.player = player
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if play { resume() }
    }

    func resume() {
        guard let player else { return }
        isPlaying = player.play()
        if !isPlaying { onFailure?("Audio playback could not start.") }
    }

    func pause() {
        player?.pause()
        tick()
        isPlaying = false
    }

    func stop() {
        player?.stop()
        player = nil
        timer?.invalidate()
        timer = nil
        isPlaying = false
        activeRange = nil
    }

    func reset() { stop(); position = 0 }

    private func tick() {
        guard let player, let chunk else { return }
        position = offset + player.currentTime
        activeRange = chunk.activeWord(at: player.currentTime)?.range
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.player === player else { return }
            self.timer?.invalidate()
            self.timer = nil
            self.isPlaying = false
            self.position = self.offset + (self.chunk?.durationMs ?? 0) / 1000
            self.activeRange = nil
            self.player = nil
            self.onBoundary?()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            guard self.player === player else { return }
            self.onFailure?(error?.localizedDescription ?? "Could not decode this audio.")
        }
    }
}
