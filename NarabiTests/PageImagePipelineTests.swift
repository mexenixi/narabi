import Testing
import UIKit
@testable import Narabi

@Suite("Page image pipeline")
struct PageImagePipelineTests {
    @Test func resizingPreservesAspectRatioAndDoesNotUpscale() {
        let source = image(size: CGSize(width: 400, height: 200), alpha: false)
        let reduced = PageImagePipeline.resizedPreservingContent(source, maximumLongEdge: 100)
        #expect(reduced.size == CGSize(width: 100, height: 50))
        let unchanged = PageImagePipeline.resizedPreservingContent(source, maximumLongEdge: 800)
        #expect(unchanged.size == CGSize(width: 400, height: 200))
    }

    @Test func workingDataUsesPNGForAlphaAndJPEGForOpaqueImages() throws {
        let transparent = image(size: CGSize(width: 20, height: 20), alpha: true)
        let opaque = image(size: CGSize(width: 20, height: 20), alpha: false)
        let png = try #require(PageImagePipeline.workingData(from: transparent))
        let jpeg = try #require(PageImagePipeline.workingData(from: opaque))
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(jpeg.starts(with: [0xFF, 0xD8]))
    }

    @Test func opaqueImageProducesFullyOpaquePixels() throws {
        let transparent = image(size: CGSize(width: 20, height: 20), alpha: true)
        let opaque = PageImagePipeline.opaqueImage(transparent)
        #expect(opaque.size == transparent.size)
        #expect(try alphaByte(atX: 0, y: 0, in: opaque) == 255)
        #expect(try alphaByte(atX: 10, y: 10, in: opaque) == 255)
    }

    private func alphaByte(atX x: Int, y: Int, in image: UIImage) throws -> UInt8 {
        let cgImage = try #require(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(
            CGContext(
                data: &pixel,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: CGFloat(-x), y: CGFloat(y - cgImage.height + 1))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return pixel[3]
    }

    private func image(size: CGSize, alpha: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !alpha
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            if !alpha {
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            UIColor.red.withAlphaComponent(alpha ? 0.5 : 1).setFill()
            context.fill(CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4))
        }
    }
}
