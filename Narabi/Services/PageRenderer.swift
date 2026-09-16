import UIKit

/// Canonical direct-clip raster renderer. It does not create a transparent padded crop image.
nonisolated enum PageRenderer {
    enum Background { case white, transparent }

    static func render(
        page: ProjectPage, maximumLongEdge: CGFloat, background: Background = .white,
        colorPolicy: ExportColorPolicy = .perPage, exactPixelSize: CGSize? = nil
    ) -> UIImage? {
        guard let raw = PageImagePipeline.baseImage(for: page) else { return nil }
        return render(
            image: raw, page: page, maximumLongEdge: maximumLongEdge, background: background,
            colorPolicy: colorPolicy, exactPixelSize: exactPixelSize)
    }

    static func render(
        image raw: UIImage, page: ProjectPage, maximumLongEdge: CGFloat,
        background: Background = .white, colorPolicy: ExportColorPolicy = .perPage,
        exactPixelSize: CGSize? = nil
    ) -> UIImage? {
        let base = PageImagePipeline.normalizedOrientation(raw)
        let canvas =
            exactPixelSize.map {
                CGSize(width: max(1, floor($0.width)), height: max(1, floor($0.height)))
            }
            ?? PageRenderGeometry.pixelCanvas(
                for: page, baseImageSize: base.size, maximumLongEdge: maximumLongEdge)
        let layout = PageRenderGeometry.rasterLayout(for: page, baseImageSize: base.size, canvasSize: canvas)
        let mode = PageColorRenderer.resolvedMode(pageMode: page.colorMode, policy: colorPolicy)
        let image = PageColorRenderer.render(base, mode: mode)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = (background == .white)
        return UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            let bounds = CGRect(origin: .zero, size: canvas)
            if background == .white {
                UIColor.white.setFill()
                context.fill(bounds)
            }
            context.cgContext.saveGState()
            context.cgContext.interpolationQuality = .high
            context.cgContext.clip(to: bounds)
            if page.outputStyle == .a4Centered {
                let center = CGPoint(x: layout.fullImageRect.midX, y: layout.fullImageRect.midY)
                context.cgContext.translateBy(x: center.x, y: center.y)
                context.cgContext.rotate(by: CGFloat(page.placementRotationDegrees * .pi / 180))
                context.cgContext.translateBy(x: -center.x, y: -center.y)
            }
            context.cgContext.clip(to: layout.visibleImageRect)
            image.draw(in: layout.fullImageRect)
            context.cgContext.restoreGState()
        }
    }
}
