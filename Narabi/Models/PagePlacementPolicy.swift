import CoreGraphics
import Foundation

/// Single source of truth shared by PageEditView, composite editor, PDF/image export and previews.
nonisolated enum PagePlacementPolicy {
    static let minimumScale = 0.05
    static let maximumScale = 8.00
    static let defaultScale = 1.00
    static let maximumCropSum = 0.95

    /// Non-linear UI mapping: 0...0.58 gives 5...100%, 0.58...1 gives 100...800%.
    static func scale(fromSlider value: Double) -> Double {
        let v = min(max(value, 0), 1)
        if v <= 0.58 {
            let t = v / 0.58
            return minimumScale * pow(defaultScale / minimumScale, t)
        }
        let t = (v - 0.58) / 0.42
        return defaultScale * pow(maximumScale / defaultScale, t)
    }

    static func slider(fromScale scale: Double) -> Double {
        let s = min(max(scale, minimumScale), maximumScale)
        if s <= defaultScale {
            return 0.58 * log(s / minimumScale) / log(defaultScale / minimumScale)
        }
        return 0.58 + 0.42 * log(s / defaultScale) / log(maximumScale / defaultScale)
    }

    /// Center-based absolute normalized coordinates. Range grows with displayed image size.
    static func offsetLimit(canvas: CGSize, image: CGSize, scale: Double, rotationDegrees: Double = 0)
        -> CGSize
    {
        guard canvas.width > 0, canvas.height > 0, image.width > 0, image.height > 0 else {
            return CGSize(width: 1, height: 1)
        }
        let radians = CGFloat(rotationDegrees * .pi / 180)
        let cosine = abs(cos(radians))
        let sine = abs(sin(radians))
        let scaledWidth = image.width * scale
        let scaledHeight = image.height * scale
        let rotatedWidth = scaledWidth * cosine + scaledHeight * sine
        let rotatedHeight = scaledWidth * sine + scaledHeight * cosine
        return CGSize(
            width: max(1, 1 + rotatedWidth / canvas.width),
            height: max(1, 1 + rotatedHeight / canvas.height))
    }

    /// Calculates the normalized movement range shared by normal page placement and Composite placement.
    /// The image size must already have its orientation normalized. Crop does not affect this range.
    static func placementOffsetLimits(
        paperSize: CGSize,
        normalizedImageSize: CGSize,
        placementScale: Double,
        rotationDegrees: Double
    ) -> CGSize {
        let imageWidth = CGFloat(clampedScale(placementScale))
        let imageHeight =
            imageWidth * paperSize.width / max(paperSize.height, 1)
            * normalizedImageSize.height / max(normalizedImageSize.width, 1)
        return offsetLimit(
            canvas: CGSize(width: 1, height: 1),
            image: CGSize(width: imageWidth, height: imageHeight),
            scale: 1,
            rotationDegrees: rotationDegrees
        )
    }

    static func positionDisplayValue(offset: Double, limit: Double) -> Int {
        guard limit > 0 else { return 0 }
        return Int((min(max(offset / limit, -1), 1) * 100).rounded())
    }

    static func clampedScale(_ value: Double) -> Double {
        min(max(value, minimumScale), maximumScale)
    }
}

nonisolated enum PageCropEdge: CaseIterable {
    case left
    case right
    case top
    case bottom
}

nonisolated struct PageCropInsets: Codable, Equatable {
    var left: Double = 0
    var right: Double = 0
    var top: Double = 0
    var bottom: Double = 0

    mutating func setLeft(_ value: Double) {
        left = min(max(value, 0), PagePlacementPolicy.maximumCropSum - right)
    }
    mutating func setRight(_ value: Double) {
        right = min(max(value, 0), PagePlacementPolicy.maximumCropSum - left)
    }
    mutating func setTop(_ value: Double) {
        top = min(max(value, 0), PagePlacementPolicy.maximumCropSum - bottom)
    }
    mutating func setBottom(_ value: Double) {
        bottom = min(max(value, 0), PagePlacementPolicy.maximumCropSum - top)
    }

    mutating func set(_ value: Double, for edge: PageCropEdge) {
        switch edge {
        case .left:
            setLeft(value)
        case .right:
            setRight(value)
        case .top:
            setTop(value)
        case .bottom:
            setBottom(value)
        }
    }
}
