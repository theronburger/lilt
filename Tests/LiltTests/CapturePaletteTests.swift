import XCTest
import AppKit
@testable import Lilt

final class CapturePaletteTests: XCTestCase {
    func testForegroundMeetsTextContrastAcrossColors() throws {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        for r in stride(from: 0.0, through: 1.0, by: 0.1) {
            for g in stride(from: 0.0, through: 1.0, by: 0.1) {
                for b in stride(from: 0.0, through: 1.0, by: 0.1) {
                    let palette = CapturePalette(red: r, green: g, blue: b)
                    let luminance = 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
                    let contrast = palette.foreground == .black ? (luminance + 0.05) / 0.05 : 1.05 / (luminance + 0.05)
                    XCTAssertGreaterThanOrEqual(contrast, 4.5)
                }
            }
        }
    }

    @MainActor func testBottomThreeRowsIgnoreContrastingContentAbove() throws {
        for background in [NSColor.white, NSColor.black] {
            let image = try boundaryImage(rows: [background, background, background], height: 100)
            let sampled = try XCTUnwrap(CapturePalette(image: image).background.usingColorSpace(.sRGB))
            let expected = try XCTUnwrap(background.usingColorSpace(.sRGB))
            XCTAssertEqual(sampled.redComponent, expected.redComponent, accuracy: 0.005)
            XCTAssertEqual(sampled.greenComponent, expected.greenComponent, accuracy: 0.005)
            XCTAssertEqual(sampled.blueComponent, expected.blueComponent, accuracy: 0.005)
        }
    }

    @MainActor func testAveragesEveryBottomRowAndHandlesShortImages() throws {
        for rows in [[NSColor.red, .green, .blue], [NSColor.red, .blue]] {
            let image = try boundaryImage(rows: rows, height: rows.count == 2 ? 2 : 100)
            let sampled = try XCTUnwrap(CapturePalette(image: image).background.usingColorSpace(.sRGB))
            XCTAssertEqual(sampled.redComponent, 1 / Double(rows.count), accuracy: 0.005)
            XCTAssertEqual(sampled.blueComponent, 1 / Double(rows.count), accuracy: 0.005)
            XCTAssertEqual(sampled.greenComponent, rows.count == 2 ? 0 : 1.0 / 3, accuracy: 0.005)
        }
    }

    private func boundaryImage(rows: [NSColor], height: Int) throws -> NSImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: 100, height: height, bitsPerComponent: 8,
            bytesPerRow: 400, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(NSColor.magenta.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 100, height: height))
        for (row, color) in rows.enumerated() {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: 0, y: row, width: 100, height: 1))
        }
        return NSImage(cgImage: try XCTUnwrap(context.makeImage()), size: NSSize(width: 100, height: height))
    }
}
