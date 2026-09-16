import CoreGraphics
import Testing

@testable import Narabi

@Suite("Page placement and crop limits")
struct PagePlacementPolicyTests {
    @Test func sliderScaleRoundTripsAtKeyPoints() {
        for slider in [0.0, 0.2, 0.58, 0.75, 1.0] {
            let restored = PagePlacementPolicy.slider(
                fromScale: PagePlacementPolicy.scale(fromSlider: slider))
            #expect(abs(restored - slider) < 0.000_001)
        }
    }

    @Test func clampsScaleAtBothBounds() {
        #expect(PagePlacementPolicy.clampedScale(-100) == PagePlacementPolicy.minimumScale)
        #expect(PagePlacementPolicy.clampedScale(100) == PagePlacementPolicy.maximumScale)
    }

    @Test func invalidGeometryReturnsSafeOffsetLimit() {
        #expect(
            PagePlacementPolicy.offsetLimit(canvas: .zero, image: CGSize(width: 10, height: 10), scale: 1)
                == CGSize(width: 1, height: 1))
    }

    @Test func ninetyDegreeRotationSwapsOffsetGrowth() {
        let zero = PagePlacementPolicy.offsetLimit(
            canvas: CGSize(width: 100, height: 100), image: CGSize(width: 80, height: 20), scale: 1)
        let ninety = PagePlacementPolicy.offsetLimit(
            canvas: CGSize(width: 100, height: 100), image: CGSize(width: 80, height: 20), scale: 1,
            rotationDegrees: 90)
        #expect(abs(zero.width - ninety.height) < 0.000_001)
        #expect(abs(zero.height - ninety.width) < 0.000_001)
    }

    @Test func sharedPlacementLimitsMatchFormerFormula() {
        let paper = CGSize(width: 210, height: 297)
        let image = CGSize(width: 1600, height: 900)
        let scale = 2.25
        let rotation = 37.0
        let imageWidth = CGFloat(PagePlacementPolicy.clampedScale(scale))
        let imageHeight =
            imageWidth * paper.width / max(paper.height, 1)
            * image.height / max(image.width, 1)
        let former = PagePlacementPolicy.offsetLimit(
            canvas: CGSize(width: 1, height: 1),
            image: CGSize(width: imageWidth, height: imageHeight),
            scale: 1,
            rotationDegrees: rotation
        )
        let shared = PagePlacementPolicy.placementOffsetLimits(
            paperSize: paper,
            normalizedImageSize: image,
            placementScale: scale,
            rotationDegrees: rotation
        )
        #expect(abs(former.width - shared.width) < 0.000_001)
        #expect(abs(former.height - shared.height) < 0.000_001)
    }

    @Test func sharedPlacementLimitsHandlePortraitPaperAndWideImage() {
        let limits = PagePlacementPolicy.placementOffsetLimits(
            paperSize: CGSize(width: 210, height: 297),
            normalizedImageSize: CGSize(width: 1600, height: 900),
            placementScale: 1,
            rotationDegrees: 0
        )
        #expect(limits.width > limits.height)
        #expect(limits.width > 1)
        #expect(limits.height > 1)
    }

    @Test func sharedPlacementLimitsHandleLandscapePaperAndTallImage() {
        let limits = PagePlacementPolicy.placementOffsetLimits(
            paperSize: CGSize(width: 297, height: 210),
            normalizedImageSize: CGSize(width: 900, height: 1600),
            placementScale: 1,
            rotationDegrees: 0
        )
        #expect(limits.height > limits.width)
        #expect(limits.width > 1)
        #expect(limits.height > 1)
    }

    @Test func sharedPlacementLimitsTreatOppositeRotationsEqually() {
        let arguments = (
            paper: CGSize(width: 210, height: 297),
            image: CGSize(width: 1200, height: 800),
            scale: 1.4
        )
        let zero = PagePlacementPolicy.placementOffsetLimits(
            paperSize: arguments.paper, normalizedImageSize: arguments.image,
            placementScale: arguments.scale, rotationDegrees: 0)
        let oneEighty = PagePlacementPolicy.placementOffsetLimits(
            paperSize: arguments.paper, normalizedImageSize: arguments.image,
            placementScale: arguments.scale, rotationDegrees: 180)
        let ninety = PagePlacementPolicy.placementOffsetLimits(
            paperSize: arguments.paper, normalizedImageSize: arguments.image,
            placementScale: arguments.scale, rotationDegrees: 90)
        let twoSeventy = PagePlacementPolicy.placementOffsetLimits(
            paperSize: arguments.paper, normalizedImageSize: arguments.image,
            placementScale: arguments.scale, rotationDegrees: 270)
        #expect(abs(zero.width - oneEighty.width) < 0.000_001)
        #expect(abs(zero.height - oneEighty.height) < 0.000_001)
        #expect(abs(ninety.width - twoSeventy.width) < 0.000_001)
        #expect(abs(ninety.height - twoSeventy.height) < 0.000_001)
    }

    @Test func sharedPlacementLimitsClampScaleWithoutChangingUIScreenRanges() {
        let paper = CGSize(width: 210, height: 297)
        let image = CGSize(width: 1000, height: 500)
        let below = PagePlacementPolicy.placementOffsetLimits(
            paperSize: paper, normalizedImageSize: image,
            placementScale: -100, rotationDegrees: 15)
        let minimum = PagePlacementPolicy.placementOffsetLimits(
            paperSize: paper, normalizedImageSize: image,
            placementScale: PagePlacementPolicy.minimumScale, rotationDegrees: 15)
        let above = PagePlacementPolicy.placementOffsetLimits(
            paperSize: paper, normalizedImageSize: image,
            placementScale: 100, rotationDegrees: 15)
        let maximum = PagePlacementPolicy.placementOffsetLimits(
            paperSize: paper, normalizedImageSize: image,
            placementScale: PagePlacementPolicy.maximumScale, rotationDegrees: 15)
        #expect(abs(below.width - minimum.width) < 0.000_001)
        #expect(abs(below.height - minimum.height) < 0.000_001)
        #expect(abs(above.width - maximum.width) < 0.000_001)
        #expect(abs(above.height - maximum.height) < 0.000_001)
    }

    @Test func sharedPlacementLimitsPreserveCurrentSafeFallbacks() {
        let zeroPaper = PagePlacementPolicy.placementOffsetLimits(
            paperSize: .zero,
            normalizedImageSize: CGSize(width: 100, height: 50),
            placementScale: 1,
            rotationDegrees: 0
        )
        let zeroImage = PagePlacementPolicy.placementOffsetLimits(
            paperSize: CGSize(width: 210, height: 297),
            normalizedImageSize: .zero,
            placementScale: 1,
            rotationDegrees: 0
        )
        #expect(zeroPaper.width >= 1 && zeroPaper.height >= 1)
        #expect(zeroImage.width >= 1 && zeroImage.height >= 1)
    }

    @Test func displayPositionClampsToPercentRange() {
        #expect(PagePlacementPolicy.positionDisplayValue(offset: 99, limit: 2) == 100)
        #expect(PagePlacementPolicy.positionDisplayValue(offset: -99, limit: 2) == -100)
        #expect(PagePlacementPolicy.positionDisplayValue(offset: 1, limit: 2) == 50)
        #expect(PagePlacementPolicy.positionDisplayValue(offset: 1, limit: 0) == 0)
    }

    @Test func cropInsetsRejectNegativeValues() {
        var crop = PageCropInsets()
        crop.setLeft(-1)
        crop.setTop(-1)
        #expect(crop.left == 0)
        #expect(crop.top == 0)
    }

    @Test func horizontalCropNeverExceedsMaximumSum() {
        var crop = PageCropInsets()
        crop.setLeft(0.8)
        crop.setRight(0.8)
        #expect(crop.left + crop.right <= PagePlacementPolicy.maximumCropSum)
        #expect(crop.right == PagePlacementPolicy.maximumCropSum - crop.left)
    }

    @Test func verticalCropNeverExceedsMaximumSum() {
        var crop = PageCropInsets()
        crop.setBottom(0.7)
        crop.setTop(0.7)
        #expect(crop.top + crop.bottom <= PagePlacementPolicy.maximumCropSum)
        #expect(crop.top == PagePlacementPolicy.maximumCropSum - crop.bottom)
    }

    @Test func changingOneEdgeRespectsTheOppositeEdge() {
        var crop = PageCropInsets(left: 0.3, right: 0.4, top: 0.2, bottom: 0.25)
        crop.setLeft(0.9)
        crop.setBottom(0.9)
        #expect(crop.left == PagePlacementPolicy.maximumCropSum - 0.4)
        #expect(crop.bottom == PagePlacementPolicy.maximumCropSum - 0.2)
    }

    @Test func cropEdgeSetterTargetsExplicitEdgeWhenAllValuesMatch() {
        for edge in PageCropEdge.allCases {
            var crop = PageCropInsets(left: 0, right: 0, top: 0, bottom: 0)
            crop.set(0.4, for: edge)
            switch edge {
            case .left:
                #expect(crop == PageCropInsets(left: 0.4, right: 0, top: 0, bottom: 0))
            case .right:
                #expect(crop == PageCropInsets(left: 0, right: 0.4, top: 0, bottom: 0))
            case .top:
                #expect(crop == PageCropInsets(left: 0, right: 0, top: 0.4, bottom: 0))
            case .bottom:
                #expect(crop == PageCropInsets(left: 0, right: 0, top: 0, bottom: 0.4))
            }
        }
    }

    @Test func cropEdgeSetterUsesTheCorrectOppositeEdge() {
        var horizontal = PageCropInsets(left: 0.3, right: 0.3, top: 0, bottom: 0)
        horizontal.set(0.9, for: .right)
        #expect(horizontal.left == 0.3)
        #expect(horizontal.right == PagePlacementPolicy.maximumCropSum - 0.3)

        var vertical = PageCropInsets(left: 0, right: 0, top: 0.25, bottom: 0.25)
        vertical.set(0.9, for: .bottom)
        #expect(vertical.top == 0.25)
        #expect(vertical.bottom == PagePlacementPolicy.maximumCropSum - 0.25)
    }
}
