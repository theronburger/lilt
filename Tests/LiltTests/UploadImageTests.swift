import XCTest
import AppKit
@testable import Lilt

final class UploadImageTests: XCTestCase {
    func testResizePreservesAspectAndSmallText() throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 2400, height: 1200, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        let normal = try UploadImage.prepare(image, minimumWordHeight: 30)
        XCTAssertEqual(normal.width, 1600); XCTAssertEqual(normal.height, 800)
        let small = try UploadImage.prepare(image, minimumWordHeight: 12)
        XCTAssertEqual(small.width, 2400); XCTAssertEqual(small.height, 1200)
        XCTAssertEqual(normal.mime, "image/png")
        XCTAssertNotNil(NSImage(data: normal.data))
        let jpeg = try UploadImage.prepare(image, jpeg: true)
        XCTAssertEqual(jpeg.mime, "image/jpeg")
        XCTAssertNotNil(NSImage(data: jpeg.data))
    }
    func testOptimizedNeverInflatesPayloadAndPreservesSmallText() throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 2400, height: 1200, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(NSColor.white.cgColor); context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1200))
        let image = try XCTUnwrap(context.makeImage())
        let original = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        let optimized = try UploadImage.optimized(image, minimumWordHeight: 12)
        XCTAssertEqual(optimized.width, image.width)
        XCTAssertLessThanOrEqual(optimized.data.count, original.count)
        XCTAssertNotNil(NSImage(data: optimized.data))
    }

}
