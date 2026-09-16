import CoreImage
import UIKit
import Vision

struct EditableQuad: Equatable, Sendable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomLeft: CGPoint
    var bottomRight: CGPoint

    static let insetDefault = EditableQuad(
        topLeft: CGPoint(x: 0.06, y: 0.06),
        topRight: CGPoint(x: 0.94, y: 0.06),
        bottomLeft: CGPoint(x: 0.06, y: 0.94),
        bottomRight: CGPoint(x: 0.94, y: 0.94)
    )

    init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    nonisolated init(_ value: VNRectangleObservation) {
        func ui(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x, y: 1 - point.y)
        }
        topLeft = ui(value.topLeft)
        topRight = ui(value.topRight)
        bottomLeft = ui(value.bottomLeft)
        bottomRight = ui(value.bottomRight)
    }

    nonisolated var area: CGFloat {
        let points = [topLeft, topRight, bottomRight, bottomLeft]
        return abs(
            zip(points, points.dropFirst() + [points[0]]).reduce(CGFloat.zero) {
                $0 + $1.0.x * $1.1.y - $1.1.x * $1.0.y
            }) / 2
    }

    nonisolated var centerDistance: CGFloat {
        let center = CGPoint(
            x: (topLeft.x + topRight.x + bottomLeft.x + bottomRight.x) / 4,
            y: (topLeft.y + topRight.y + bottomLeft.y + bottomRight.y) / 4
        )
        return hypot(center.x - 0.5, center.y - 0.5)
    }
}

nonisolated enum DocumentRectangleDetector {
    struct Pass: Sendable {
        let confidence: Float
        let size: Float
        let tolerance: Float
        let minRatio: Float
        let maxRatio: Float
    }

    static let passes = [
        Pass(confidence: 0.70, size: 0.35, tolerance: 25, minRatio: 0.45, maxRatio: 1.0),
        Pass(confidence: 0.50, size: 0.18, tolerance: 35, minRatio: 0.25, maxRatio: 1.0),
        Pass(confidence: 0.30, size: 0.08, tolerance: 45, minRatio: 0.12, maxRatio: 1.0),
    ]

    static func detect(in image: UIImage) -> [EditableQuad] {
        guard let cgImage = image.cgImage else { return [] }
        var all: [EditableQuad] = []
        for pass in passes {
            let request = VNDetectRectanglesRequest()
            request.maximumObservations = 8
            request.minimumConfidence = pass.confidence
            request.minimumSize = pass.size
            request.quadratureTolerance = pass.tolerance
            request.minimumAspectRatio = pass.minRatio
            request.maximumAspectRatio = pass.maxRatio
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            try? handler.perform([request])
            all.append(contentsOf: (request.results ?? []).map(EditableQuad.init))
            if !all.isEmpty { break }
        }
        return rankedUnique(all)
    }

    static func rankedUnique(_ values: [EditableQuad], limit: Int = 5) -> [EditableQuad] {
        guard limit > 0 else { return [] }
        var unique: [EditableQuad] = []
        for value in values.sorted(by: { score($0) > score($1) }) {
            if !unique.contains(where: { near($0, value) }) { unique.append(value) }
        }
        return Array(unique.prefix(limit))
    }

    static func score(_ quad: EditableQuad) -> CGFloat {
        quad.area * 2.2 - quad.centerDistance * 0.35
    }

    static func near(_ first: EditableQuad, _ second: EditableQuad) -> Bool {
        abs(first.area - second.area) < 0.025
            && hypot(
                first.topLeft.x - second.topLeft.x,
                first.topLeft.y - second.topLeft.y
            ) < 0.05
    }
}

nonisolated enum DocumentPerspectiveCorrector {
    static func correct(_ image: UIImage, quad: EditableQuad) -> UIImage? {
        guard let input = CIImage(image: image) else { return nil }
        let width = input.extent.width
        let height = input.extent.height
        func vector(_ point: CGPoint) -> CIVector {
            CIVector(x: point.x * width, y: (1 - point.y) * height)
        }
        let output = input.applyingFilter(
            "CIPerspectiveCorrection",
            parameters: [
                "inputTopLeft": vector(quad.topLeft),
                "inputTopRight": vector(quad.topRight),
                "inputBottomLeft": vector(quad.bottomLeft),
                "inputBottomRight": vector(quad.bottomRight),
            ]
        )
        guard !output.extent.isEmpty else { return nil }
        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

extension UIImage {
    func normalizedForDocumentCorrection() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
