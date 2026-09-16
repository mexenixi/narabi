import Testing
import UIKit

@testable import Narabi

@MainActor
struct DocumentCorrectionEngineTests {
    private func quad(inset: CGFloat) -> EditableQuad {
        EditableQuad(
            topLeft: CGPoint(x: inset, y: inset),
            topRight: CGPoint(x: 1 - inset, y: inset),
            bottomLeft: CGPoint(x: inset, y: 1 - inset),
            bottomRight: CGPoint(x: 1 - inset, y: 1 - inset)
        )
    }

    private func image(width: CGFloat = 120, height: CGFloat = 80) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.black.setFill()
            context.fill(CGRect(x: 12, y: 10, width: width - 24, height: height - 20))
        }
    }

    @Test func insetDefaultUsesSixPercentMargins() {
        let value = EditableQuad.insetDefault
        #expect(value.topLeft == CGPoint(x: 0.06, y: 0.06))
        #expect(value.topRight == CGPoint(x: 0.94, y: 0.06))
        #expect(value.bottomLeft == CGPoint(x: 0.06, y: 0.94))
        #expect(value.bottomRight == CGPoint(x: 0.94, y: 0.94))
    }

    @Test func fullFrameAreaIsOneAndCenterDistanceIsZero() {
        let value = quad(inset: 0)
        #expect(abs(value.area - 1) < 0.000_001)
        #expect(abs(value.centerDistance) < 0.000_001)
    }

    @Test func scoringPrefersLargerCenteredCandidate() {
        #expect(
            DocumentRectangleDetector.score(quad(inset: 0.05))
                > DocumentRectangleDetector.score(quad(inset: 0.30))
        )
    }

    @Test func nearCandidatesAreDeduplicated() {
        let first = quad(inset: 0.10)
        let near = EditableQuad(
            topLeft: CGPoint(x: 0.11, y: 0.11),
            topRight: CGPoint(x: 0.91, y: 0.11),
            bottomLeft: CGPoint(x: 0.11, y: 0.91),
            bottomRight: CGPoint(x: 0.91, y: 0.91)
        )
        let result = DocumentRectangleDetector.rankedUnique([near, first])
        #expect(result.count == 1)
    }

    @Test func rankingHonorsFiveCandidateLimit() {
        let values = (0..<8).map { index -> EditableQuad in
            let x = CGFloat(index) * 0.06
            return EditableQuad(
                topLeft: CGPoint(x: x, y: 0),
                topRight: CGPoint(x: min(x + 0.20, 1), y: 0),
                bottomLeft: CGPoint(x: x, y: 0.20),
                bottomRight: CGPoint(x: min(x + 0.20, 1), y: 0.20)
            )
        }
        #expect(DocumentRectangleDetector.rankedUnique(values).count == 5)
        #expect(DocumentRectangleDetector.rankedUnique(values, limit: 0).isEmpty)
    }

    @Test func fullFramePerspectiveCorrectionProducesImage() throws {
        let corrected = try #require(DocumentPerspectiveCorrector.correct(image(), quad: quad(inset: 0)))
        #expect(corrected.size.width > 0)
        #expect(corrected.size.height > 0)
    }

    @Test func orientationNormalizationProducesUpImageWithSameSize() {
        let source = image()
        let oriented = UIImage(cgImage: source.cgImage!, scale: 1, orientation: .left)
        let normalized = oriented.normalizedForDocumentCorrection()
        #expect(normalized.imageOrientation == .up)
        #expect(normalized.size == oriented.size)
    }
}
