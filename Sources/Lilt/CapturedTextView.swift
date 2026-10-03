import AppKit
import SwiftUI
import LiltCore

struct CapturedTextView: NSViewRepresentable {
    var image: NSImage
    var text: String
    var words: [CapturedWord]
    var activeRange: NSRange?
    var onWord: (Int) -> Void

    func makeNSView(context: Context) -> CaptureCanvas { CaptureCanvas() }

    func updateNSView(_ view: CaptureCanvas, context: Context) {
        let changed = view.image !== image || view.words != words || view.text != text
        view.image = image
        view.words = words
        view.text = text
        view.onWord = onWord
        if changed { view.rebuildAccessibility() }
        if changed || view.activeRange != activeRange {
            view.activeRange = activeRange
            view.needsDisplay = true
        }
    }
}

final class CaptureCanvas: NSView {
    var image: NSImage?
    var text = ""
    var words: [CapturedWord] = []
    var activeRange: NSRange?
    var onWord: ((Int) -> Void)?
    private var hoveredWord: CapturedWord?
    private var wordElements: [CaptureWordElement] = []
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    private var imageRect: CGRect { CaptureLayout.imageRect(size: image?.size ?? .zero, in: bounds) }

    override func draw(_ dirtyRect: NSRect) {
        image?.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        for word in words where activeRange.map(word.overlaps) ?? false {
            let path = NSBezierPath(roundedRect: word.rectangle(in: imageRect).insetBy(dx: -1, dy: -1), xRadius: 3, yRadius: 3)
            NSColor.controlAccentColor.withAlphaComponent(0.24).setFill()
            path.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.85).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
        if let word = hoveredWord {
            NSColor.controlAccentColor.withAlphaComponent(0.55).setStroke()
            let rect = word.rectangle(in: imageRect).insetBy(dx: -1, dy: -1)
            let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
            path.lineWidth = 1
            path.stroke()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    func word(at point: NSPoint) -> CapturedWord? {
        words.first { $0.rectangle(in: imageRect).insetBy(dx: -2, dy: -2).contains(point) }
    }

    override func mouseMoved(with event: NSEvent) {
        let word = word(at: convert(event.locationInWindow, from: nil))
        if hoveredWord != word { hoveredWord = word; needsDisplay = true }
        (word == nil ? NSCursor.arrow : NSCursor.pointingHand).set()
    }

    override func mouseExited(with event: NSEvent) { hoveredWord = nil; needsDisplay = true; NSCursor.arrow.set() }

    override func mouseDown(with event: NSEvent) {
        if let word = word(at: convert(event.locationInWindow, from: nil)) { onWord?(word.charIndex) }
        else { window?.performDrag(with: event) }
    }

    override func layout() { super.layout(); updateAccessibilityFrames() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); updateAccessibilityFrames() }

    func rebuildAccessibility() {
        setAccessibilityElement(false)
        wordElements = words.map { word in
            let element = CaptureWordElement()
            element.setAccessibilityRole(.button)
            element.setAccessibilityParent(self)
            if NSMaxRange(word.range) <= (text as NSString).length {
                element.setAccessibilityLabel((text as NSString).substring(with: word.range))
            }
            element.setAccessibilityHelp("Read from this word")
            element.onPress = { [weak self] in self?.onWord?(word.charIndex) }
            element.frameProvider = { [weak self] in
                guard let self, let window = self.window else { return .zero }
                return window.convertToScreen(self.convert(word.rectangle(in: self.imageRect), to: nil))
            }
            return element
        }
        setAccessibilityChildren(wordElements)
        updateAccessibilityFrames()
    }

    private func updateAccessibilityFrames() {
        guard let window else { return }
        for (word, element) in zip(words, wordElements) {
            element.setAccessibilityFrame(window.convertToScreen(convert(word.rectangle(in: imageRect), to: nil)))
        }
    }
}

private final class CaptureWordElement: NSAccessibilityElement {
    var onPress: (() -> Void)?
    var frameProvider: (() -> NSRect)?
    override func accessibilityFrame() -> NSRect { frameProvider?() ?? .zero }
    override func accessibilityPerformPress() -> Bool { onPress?(); return true }
}
