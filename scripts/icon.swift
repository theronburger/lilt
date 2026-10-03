import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let n = CGFloat(pixels)
        NSColor(calibratedRed: 0.969, green: 0.973, blue: 0.980, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: n * 0.05, y: n * 0.05, width: n * 0.90, height: n * 0.90),
                     xRadius: n * 0.20, yRadius: n * 0.20).fill()
        let unit = n * 0.64 / 56
        let inset = n * 0.18
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: inset + x * unit, y: n - inset - y * unit)
        }
        let mark = NSBezierPath()
        mark.lineWidth = 7 * unit
        mark.lineCapStyle = .round
        mark.lineJoinStyle = .round
        mark.move(to: point(12, 10))
        mark.line(to: point(12, 41))
        mark.curve(to: point(17, 46), controlPoint1: point(12, 44), controlPoint2: point(14, 46))
        mark.line(to: point(44, 46))
        mark.move(to: point(28, 18))
        mark.line(to: point(28, 32))
        mark.move(to: point(44, 10))
        mark.line(to: point(44, 32))
        NSColor(calibratedRed: 39 / 255, green: 99 / 255, blue: 231 / 255, alpha: 1).setStroke()
        mark.stroke()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
