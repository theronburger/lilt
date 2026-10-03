import AppKit
import ScreenCaptureKit

struct SelectedCapture {
    let image: CGImage
    let frame: NSRect
    let screen: NSScreen
}

@MainActor
final class ScreenSelection {
    private var windows: [NSWindow] = []
    private var previousApp: NSRunningApplication?
    var onSelect: ((SelectedCapture) -> Void)?
    var onCancel: (() -> Void)?

    func begin() async throws {
        guard windows.isEmpty else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        var snapshots: [(NSScreen, CGImage)] = []
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let display = content.displays.first(where: { $0.displayID == number.uint32Value }) else { continue }
            let config = SCStreamConfiguration()
            config.width = Int(screen.frame.width * screen.backingScaleFactor)
            config.height = Int(screen.frame.height * screen.backingScaleFactor)
            config.showsCursor = false
            let ownWindows = content.windows.filter { $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier }
            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
            snapshots.append((screen, try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)))
        }
        guard !snapshots.isEmpty else {
            throw NSError(domain: "Lilt", code: 3, userInfo: [NSLocalizedDescriptionKey: "No screen is available to capture."])
        }
        for (screen, image) in snapshots {
            let window = SelectionWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isOpaque = true
            window.isReleasedWhenClosed = false
            let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size), image: image)
            view.onCancel = { [weak self] in self?.cancel() }
            view.onSelect = { [weak self] rect in
                let scaleX = CGFloat(image.width) / screen.frame.width
                let scaleY = CGFloat(image.height) / screen.frame.height
                let pixels = NSRect(x: rect.minX * scaleX, y: rect.minY * scaleY,
                                    width: rect.width * scaleX, height: rect.height * scaleY).integral
                guard let cropped = image.cropping(to: pixels) else { self?.cancel(); return }
                let global = NSRect(x: screen.frame.minX + rect.minX, y: screen.frame.maxY - rect.maxY,
                                    width: rect.width, height: rect.height)
                self?.finish()
                self?.onSelect?(SelectedCapture(image: cropped, frame: global, screen: screen))
            }
            window.contentView = view
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window = windows.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) { window.makeKey() }
        NSCursor.crosshair.push()
    }

    func cancel() { finish(); previousApp?.activate(); onCancel?() }

    private func finish() {
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows.removeAll()
        NSCursor.pop()
    }
}

private final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class SelectionView: NSView {
    private let image: NSImage
    private var start: NSPoint?
    private var selection: NSRect?
    var onSelect: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init(frame: NSRect, image: CGImage) {
        self.image = NSImage(cgImage: image, size: frame.size)
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        let shade = NSBezierPath(rect: bounds)
        if let selection { shade.appendRect(selection) }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.4).setFill()
        shade.fill()
        if let selection {
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selection)
            border.lineWidth = 1.5
            border.stroke()
        }
        let help = "Drag over text to read it   ·   esc to cancel"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium), .foregroundColor: NSColor.white
        ]
        let size = (help as NSString).size(withAttributes: attributes)
        let pill = NSRect(x: (bounds.width - size.width) / 2 - 18, y: 55, width: size.width + 36, height: 40)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: pill, xRadius: 20, yRadius: 20).fill()
        (help as NSString).draw(at: NSPoint(x: pill.minX + 18, y: pill.minY + 10), withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) { start = convert(event.locationInWindow, from: nil); selection = nil }
    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let point = convert(event.locationInWindow, from: nil)
        selection = NSRect(x: min(start.x, point.x), y: min(start.y, point.y),
                           width: abs(start.x - point.x), height: abs(start.y - point.y)).intersection(bounds)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        guard let selection, selection.width >= 12, selection.height >= 12 else { return }
        onSelect?(selection)
    }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { onCancel?() } }
    override func rightMouseDown(with event: NSEvent) { onCancel?() }
}
