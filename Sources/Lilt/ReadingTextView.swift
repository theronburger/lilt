import SwiftUI
import AppKit

struct ReadingTextView: NSViewRepresentable {
    var text: String
    var fontSize: Double
    var activeRange: NSRange?
    var onWord: (Int) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let view = WordTextView(frame: .zero)
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.isRichText = false
        view.textContainerInset = NSSize(width: 32, height: 28)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude)
        view.setAccessibilityLabel("Reading text. Click a word to hear it.")
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? WordTextView else { return }
        view.onWord = onWord
        let changedText = view.string != text
        if changedText || view.font?.pointSize != CGFloat(fontSize) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = fontSize * 0.38
            paragraph.paragraphSpacing = fontSize * 0.5
            let font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
            view.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph
            ]))
            view.font = font
            view.lastRange = nil
            if changedText { scroll.contentView.scroll(to: .zero) }
        }
        guard view.lastRange != activeRange else { return }
        if let previous = view.lastRange, NSMaxRange(previous) <= (text as NSString).length {
            view.layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: previous)
            view.layoutManager?.removeTemporaryAttribute(.foregroundColor, forCharacterRange: previous)
        }
        if let range = activeRange, NSMaxRange(range) <= (text as NSString).length {
            view.layoutManager?.addTemporaryAttributes([
                .backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.26),
                .foregroundColor: NSColor.labelColor
            ], forCharacterRange: range)
            if Date().timeIntervalSince(view.lastManualScroll) > 3,
               let layout = view.layoutManager, let container = view.textContainer {
                let glyphs = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                var rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
                rect.origin.x += view.textContainerOrigin.x
                rect.origin.y += view.textContainerOrigin.y
                let visible = scroll.documentVisibleRect.insetBy(dx: 0, dy: 40)
                if !visible.contains(rect) { view.scrollRangeToVisible(range) }
            }
        }
        view.lastRange = activeRange
    }
}

private final class WordTextView: NSTextView {
    var onWord: ((Int) -> Void)?
    var lastRange: NSRange?
    var lastManualScroll = Date.distantPast
    private var downPoint: NSPoint?

    override func mouseDown(with event: NSEvent) {
        downPoint = convert(event.locationInWindow, from: nil)
        super.mouseDown(with: event)
        guard let downPoint, let upEvent = NSApp.currentEvent else { return }
        let upPoint = convert(upEvent.locationInWindow, from: nil)
        guard hypot(upPoint.x - downPoint.x, upPoint.y - downPoint.y) < 5,
              selectedRange().length == 0, let layoutManager, let textContainer else { return }
        let point = NSPoint(x: downPoint.x - textContainerOrigin.x, y: downPoint.y - textContainerOrigin.y)
        var fraction: CGFloat = 0
        let index = layoutManager.characterIndex(for: point, in: textContainer,
                                                 fractionOfDistanceBetweenInsertionPoints: &fraction)
        let length = (string as NSString).length
        guard index < length else { return }
        let range = NSRange(location: index, length: 1)
        let glyph = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        guard layoutManager.boundingRect(forGlyphRange: glyph, in: textContainer).insetBy(dx: -2, dy: -4).contains(point) else { return }
        onWord?(index)
    }

    override func scrollWheel(with event: NSEvent) { lastManualScroll = Date(); super.scrollWheel(with: event) }
}
