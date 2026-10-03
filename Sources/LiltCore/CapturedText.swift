import Foundation
import CoreGraphics

public struct CapturedWord: Codable, Equatable, Sendable {
    public var charIndex: Int
    public var charLength: Int
    public var bounds: CGRect

    public init(charIndex: Int, charLength: Int, bounds: CGRect) {
        self.charIndex = charIndex
        self.charLength = charLength
        self.bounds = bounds
    }

    public var range: NSRange { NSRange(location: charIndex, length: charLength) }
    public func overlaps(_ range: NSRange) -> Bool { NSIntersectionRange(self.range, range).length > 0 }

    public func rectangle(in imageRect: CGRect) -> CGRect {
        CGRect(x: imageRect.minX + bounds.minX * imageRect.width,
               y: imageRect.minY + bounds.minY * imageRect.height,
               width: bounds.width * imageRect.width, height: bounds.height * imageRect.height)
    }
}

public struct CapturedText: Codable, Sendable {
    public var text: String
    public var words: [CapturedWord]

    public init(text: String, words: [CapturedWord]) { self.text = text; self.words = words }
}

public struct CaptureSnapshot: Codable, Sendable {
    public var pointSize: CGSize
    public var words: [CapturedWord]

    public init(pointSize: CGSize, words: [CapturedWord]) { self.pointSize = pointSize; self.words = words }
}

public enum CaptureLayout {
    public static let controlsHeight: CGFloat = 44
    public static let shadowInset: CGFloat = 16
    public static let minimumWidth: CGFloat = 280

    public static func imageRect(size: CGSize, in bounds: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: bounds.midX - fitted.width / 2, y: bounds.midY - fitted.height / 2,
                      width: fitted.width, height: fitted.height)
    }

    public static func windowFrame(around capture: CGRect, visibleFrame: CGRect) -> CGRect {
        let available = visibleFrame.insetBy(dx: shadowInset, dy: shadowInset)
        let scale = min(1, available.width / max(capture.width, 1),
                        available.height / max(capture.height, 1))
        let width = max(1, capture.width * scale)
        let height = max(1, capture.height * scale)
        let x = min(max(capture.minX, available.minX), available.maxX - width)
        let y = min(max(capture.maxY - height, available.minY), available.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height).insetBy(dx: -shadowInset, dy: -shadowInset)
    }

    public static func controlsFrame(below image: CGRect, visibleFrame: CGRect) -> CGRect {
        let available = visibleFrame.insetBy(dx: 8, dy: 8)
        let width = min(available.width, max(minimumWidth, min(image.width, 480)))
        let x = min(max(image.midX - width / 2, available.minX), available.maxX - width)
        let below = image.minY - controlsHeight - 6
        let y = below >= available.minY ? below : min(image.maxY + 6, available.maxY - controlsHeight)
        return CGRect(x: x, y: y, width: width, height: controlsHeight)
    }
}
