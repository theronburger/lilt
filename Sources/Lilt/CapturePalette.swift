import AppKit

struct CapturePalette {
    var background: NSColor = .white
    var foreground: NSColor = .black

    init(image: NSImage? = nil) {
        self.init(red: 1, green: 1, blue: 1)
        guard let image, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let height = min(3, cg.height)
        let width = cg.width
        guard let strip = cg.cropping(to: CGRect(x: 0, y: cg.height - height, width: cg.width, height: height)) else { return }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.interpolationQuality = .none
            context.draw(strip, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return }
        var red = 0.0, green = 0.0, blue = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            red += Double(pixels[index])
            green += Double(pixels[index + 1])
            blue += Double(pixels[index + 2])
        }
        let divisor = Double(width * height) * 255
        self = CapturePalette(red: red / divisor, green: green / divisor, blue: blue / divisor)
    }

    init(red: Double, green: Double, blue: Double) {
        background = NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        foreground = (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05) ? .black : .white
    }
}
