import AppKit

struct UploadImage {
    let data: Data
    let mime: String
    let width: Int
    let height: Int

    /// Keep text legible and send whichever encoding actually saves bytes.
    static func optimized(_ image: CGImage, minimumWordHeight: CGFloat? = nil) throws -> UploadImage {
        guard let original = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw FilterError.incomplete }
        let png = try prepare(image, minimumWordHeight: minimumWordHeight)
        let jpeg = try prepare(image, minimumWordHeight: minimumWordHeight, jpeg: true)
        // Prefer lossless text unless JPEG produces a material saving.
        let lossless = original.count < png.data.count ? UploadImage(data: original, mime: "image/png", width: image.width, height: image.height) : png
        return jpeg.data.count < Int(Double(lossless.data.count) * 0.8) ? jpeg : lossless
    }

    static func prepare(_ image: CGImage, minimumWordHeight: CGFloat? = nil, jpeg: Bool = false, maxDimension: CGFloat = 1600) throws -> UploadImage {
        var scale = min(1, maxDimension / CGFloat(max(image.width, image.height)))
        // Do not shrink small OCR text below 16 pixels high.
        if let height = minimumWordHeight, height > 0 { scale = min(1, max(scale, 16 / height)) }
        let width = max(1, Int(ceil(CGFloat(image.width) * scale)))
        let height = max(1, Int(ceil(CGFloat(image.height) * scale)))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw FilterError.incomplete }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = context.makeImage(), let data = NSBitmapImageRep(cgImage: scaled).representation(using: jpeg ? .jpeg : .png,
            properties: jpeg ? [.compressionFactor: 0.85] : [:]) else { throw FilterError.incomplete }
        return UploadImage(data: data, mime: jpeg ? "image/jpeg" : "image/png", width: width, height: height)
    }
}
