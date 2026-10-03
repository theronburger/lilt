import AppKit
import SwiftUI
import LiltCore

@MainActor
final class CaptureControlsPanel {
    private weak var reader: NSPanel?
    private let panel: NSPanel
    private var timer: Timer?
    private var lastHover = Date.distantPast
    private var visible = false
    private var keyboardVisible = false
    private var menuTracking = false
    private var menuObservers: [NSObjectProtocol] = []

    init(reader: NSPanel, model: AppModel) {
        self.reader = reader
        panel = ControlsPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        let host = NSHostingView(rootView: CaptureControlsView(model: model, playback: model.playback))
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = CaptureLayout.controlsHeight / 2
            glass.contentView = host
            panel.contentView = glass
        } else {
            let blur = NSVisualEffectView()
            blur.material = .popover
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.wantsLayer = true
            blur.layer?.cornerRadius = CaptureLayout.controlsHeight / 2
            blur.layer?.masksToBounds = true
            host.autoresizingMask = [.width, .height]
            blur.addSubview(host)
            panel.contentView = blur
        }
        timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        for (name, tracking) in [(NSMenu.didBeginTrackingNotification, true), (NSMenu.didEndTrackingNotification, false)] {
            menuObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.menuTracking = tracking
                    if !tracking { self.lastHover = Date() }
                }
            })
        }
    }

    deinit {
        timer?.invalidate()
        menuObservers.forEach(NotificationCenter.default.removeObserver)
    }

    func hide() {
        visible = false
        keyboardVisible = false
        reader?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    func showForKeyboard() {
        keyboardVisible = true
        update(preserveKeyboard: true)
        panel.makeKey()
        panel.selectNextKeyView(nil)
    }

    private func update(preserveKeyboard: Bool = false) {
        guard let reader, reader.isVisible, let screen = reader.screen else { hide(); return }
        let frame = CaptureLayout.controlsFrame(below: reader.frame.insetBy(dx: CaptureLayout.shadowInset, dy: CaptureLayout.shadowInset), visibleFrame: screen.visibleFrame)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        let point = NSEvent.mouseLocation
        let hovering = reader.frame.contains(point) || (visible && panel.frame.insetBy(dx: -6, dy: -6).contains(point))
        if hovering { lastHover = Date() }
        if !preserveKeyboard && keyboardVisible && visible && !panel.isKeyWindow { keyboardVisible = false }
        let shouldShow = (visible && menuTracking) || hovering || Date().timeIntervalSince(lastHover) < 0.3 || keyboardVisible || NSWorkspace.shared.isVoiceOverEnabled
        guard visible != shouldShow else { return }
        visible = shouldShow
        if shouldShow {
            panel.alphaValue = 0
            reader.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.16
            panel.animator().alphaValue = shouldShow ? 1 : 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.visible else { return }
                self.reader?.removeChildWindow(self.panel)
                self.panel.orderOut(nil)
            }
        }
    }
}

private final class ControlsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
