import CoreGraphics

/// Shared, side-effect-free geometry foundation for every preview and export route.
nonisolated enum PageRenderGeometry {
    static let unknownPhysicalLongEdgeMM = 300.0

    struct PaperChoice: Equatable {
        var preset: PaperPreset
        var orientation: PaperOrientation
        var widthMM: Double
        var heightMM: Double
        var unit: PaperUnit
    }

    static func paperChoice(for page: ProjectPage, baseImageSize: CGSize) -> PaperChoice {
        if page.outputStyle == .a4Centered {
            let size = page.paperPreset.sizeMM(
                orientation: page.paperOrientation, customWidthMM: page.customPaperWidthMM,
                customHeightMM: page.customPaperHeightMM)
            return matchedPaper(
                widthMM: Double(size.width), heightMM: Double(size.height), unit: page.paperUnit,
                allowPresetMatch: true)
        }
        if page.hasTrustedPhysicalSize, let width = page.sourcePhysicalWidthMM,
            let height = page.sourcePhysicalHeightMM, width > 0, height > 0
        {
            return matchedPaper(
                widthMM: width, heightMM: height, unit: page.paperUnit, allowPresetMatch: true)
        }
        let aspect = max(Double(baseImageSize.width / max(baseImageSize.height, 1)), 0.0001)
        let size: (Double, Double) =
            aspect >= 1
            ? (unknownPhysicalLongEdgeMM, unknownPhysicalLongEdgeMM / aspect)
            : (unknownPhysicalLongEdgeMM * aspect, unknownPhysicalLongEdgeMM)
        return matchedPaper(widthMM: size.0, heightMM: size.1, unit: page.paperUnit, allowPresetMatch: false)
    }

    static func matchedPaper(widthMM: Double, heightMM: Double, unit: PaperUnit, allowPresetMatch: Bool)
        -> PaperChoice
    {
        let width = max(widthMM, 1)
        let height = max(heightMM, 1)
        if allowPresetMatch {
            for preset in PaperPreset.allCases where preset != .custom {
                guard let base = preset.baseSizeMM else { continue }
                for orientation in PaperOrientation.allCases {
                    let c = orientation == .portrait ? base : CGSize(width: base.height, height: base.width)
                    if abs(width - Double(c.width)) <= max(1, Double(c.width) * 0.005),
                        abs(height - Double(c.height)) <= max(1, Double(c.height) * 0.005)
                    {
                        return PaperChoice(
                            preset: preset, orientation: orientation, widthMM: width, heightMM: height,
                            unit: unit)
                    }
                }
            }
        }
        return PaperChoice(
            preset: .custom, orientation: .portrait, widthMM: width, heightMM: height, unit: unit)
    }

    struct RasterLayout: Equatable {
        var canvasSize: CGSize
        var fullImageRect: CGRect
        var visibleImageRect: CGRect
    }

    /// Calculates the same image rectangle and crop visibility for thumbnails and final output.
    /// Crop changes visibility only in placement mode; it never recenters or rescales the full image rectangle.
    static func rasterLayout(for page: ProjectPage, baseImageSize: CGSize, canvasSize: CGSize) -> RasterLayout
    {
        let canvas = CGSize(width: max(canvasSize.width, 1), height: max(canvasSize.height, 1))
        let image = CGSize(width: max(baseImageSize.width, 1), height: max(baseImageSize.height, 1))
        let crop = normalizedCrop(page.cropInsets)

        if page.outputStyle == .original {
            let visibleAspect = max(
                (image.width * (1 - crop.left - crop.right))
                    / max(image.height * (1 - crop.top - crop.bottom), 1), 0.0001)
            let output = aspectFitSize(aspect: visibleAspect, inside: canvas)
            let sourceVisibleWidth = image.width * (1 - crop.left - crop.right)
            let sourceVisibleHeight = image.height * (1 - crop.top - crop.bottom)
            let sx = output.width / max(sourceVisibleWidth, 1)
            let sy = output.height / max(sourceVisibleHeight, 1)
            let full = CGRect(
                x: (canvas.width - output.width) / 2 - image.width * crop.left * sx,
                y: (canvas.height - output.height) / 2 - image.height * crop.top * sy,
                width: image.width * sx, height: image.height * sy)
            return RasterLayout(
                canvasSize: canvas, fullImageRect: full,
                visibleImageRect: CGRect(
                    x: (canvas.width - output.width) / 2, y: (canvas.height - output.height) / 2,
                    width: output.width, height: output.height))
        }

        let scale = CGFloat(PagePlacementPolicy.clampedScale(page.a4WidthRatio))
        let drawWidth = canvas.width * scale
        let drawHeight = drawWidth / max(image.width / image.height, 0.0001)
        let full = CGRect(
            x: (canvas.width - drawWidth) / 2 + CGFloat(page.placementOffsetX) * canvas.width / 2,
            y: (canvas.height - drawHeight) / 2 + CGFloat(page.placementOffsetY) * canvas.height / 2,
            width: drawWidth, height: drawHeight)
        let visible = CGRect(
            x: full.minX + full.width * crop.left,
            y: full.minY + full.height * crop.top,
            width: full.width * (1 - crop.left - crop.right),
            height: full.height * (1 - crop.top - crop.bottom))
        return RasterLayout(
            canvasSize: canvas, fullImageRect: pixelAligned(full), visibleImageRect: pixelAligned(visible))
    }

    private static func pixelAligned(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX.rounded(.toNearestOrAwayFromZero),
            y: rect.minY.rounded(.toNearestOrAwayFromZero),
            width: rect.width.rounded(.toNearestOrAwayFromZero),
            height: rect.height.rounded(.toNearestOrAwayFromZero))
    }

    static func pixelCanvas(for page: ProjectPage, baseImageSize: CGSize, maximumLongEdge: CGFloat) -> CGSize
    {
        let sourceEdge = max(baseImageSize.width, baseImageSize.height, 1)
        let requested = maximumLongEdge > 0 ? maximumLongEdge : sourceEdge
        let edge = min(requested, sourceEdge)
        if page.outputStyle == .original {
            let crop = normalizedCrop(page.cropInsets)
            let size = CGSize(
                width: max(1, baseImageSize.width * (1 - crop.left - crop.right)),
                height: max(1, baseImageSize.height * (1 - crop.top - crop.bottom)))
            return scaled(size, to: min(edge, max(size.width, size.height, 1)))
        }
        let mm = page.paperPreset.sizeMM(
            orientation: page.paperOrientation, customWidthMM: page.customPaperWidthMM,
            customHeightMM: page.customPaperHeightMM)
        return scaled(mm, to: edge)
    }
    private static func scaled(_ size: CGSize, to edge: CGFloat) -> CGSize {
        let f = max(1, edge) / max(size.width, size.height, 1)
        return CGSize(width: max(1, floor(size.width * f)), height: max(1, floor(size.height * f)))
    }

    private static func normalizedCrop(_ value: PageCropInsets) -> (
        left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat
    ) {
        let left = CGFloat(min(max(value.left, 0), PagePlacementPolicy.maximumCropSum))
        let right = CGFloat(min(max(value.right, 0), PagePlacementPolicy.maximumCropSum - Double(left)))
        let top = CGFloat(min(max(value.top, 0), PagePlacementPolicy.maximumCropSum))
        let bottom = CGFloat(min(max(value.bottom, 0), PagePlacementPolicy.maximumCropSum - Double(top)))
        return (left, right, top, bottom)
    }

    private static func aspectFitSize(aspect: CGFloat, inside box: CGSize) -> CGSize {
        var size = CGSize(width: box.width, height: box.width / max(aspect, 0.0001))
        if size.height > box.height {
            size.height = box.height
            size.width = size.height * aspect
        }
        return size
    }

}
