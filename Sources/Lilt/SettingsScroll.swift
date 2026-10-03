import AppKit
import SwiftUI

/// Keep the native scrollbar as an overlay even when macOS uses legacy scrollers.
struct OverlayScrollbars: NSViewRepresentable {
    func makeNSView(context: Context) -> ScrollbarAnchor { ScrollbarAnchor() }
    func updateNSView(_ view: ScrollbarAnchor, context: Context) { view.configure() }

    final class ScrollbarAnchor: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.configure() }
        }

        func configure() {
            guard let scroll = enclosingScrollView else { return }
            scroll.scrollerStyle = .overlay
            scroll.autohidesScrollers = true
            scroll.drawsBackground = false
        }
    }
}

extension View {
    func settingsScrollEdges() -> some View {
        self
        .contentMargins(.top, 24, for: .scrollIndicators)
        .contentMargins(.trailing, 12, for: .scrollIndicators)
        .contentMargins(.bottom, 12, for: .scrollIndicators)
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)
                Rectangle().fill(.black)
            }
        }
    }
}
