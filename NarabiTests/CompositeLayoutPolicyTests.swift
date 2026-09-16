import Foundation
import Testing

@testable import Narabi

@MainActor
struct CompositeLayoutPolicyTests {
    @Test func firstCompletelyUneditedPageStartsAtFullWidth() {
        let pages = CompositeLayoutPolicy.workingPages(
            from: [page(1)], paperPreset: .a4, paperOrientation: .portrait, customWidthMM: 210,
            customHeightMM: 297, paperUnit: .millimeter)
        #expect(pages[0].a4WidthRatio == 1)
        #expect(pages[0].outputStyle == .a4Centered)
    }

    @Test func laterUnplacedPagesStartAtFortyPercent() {
        let pages = CompositeLayoutPolicy.workingPages(
            from: [page(1), page(2)], paperPreset: .a4, paperOrientation: .portrait, customWidthMM: 210,
            customHeightMM: 297, paperUnit: .millimeter)
        #expect(pages[1].a4WidthRatio == 0.40)
        #expect(pages[1].placementOffsetX == 0)
        #expect(pages[1].placementOffsetY == 0)
        #expect(pages[1].placementRotationDegrees == 0)
    }

    @Test func editedFirstPageStartsAtFortyPercentWhenPlacementIsNotSaved() {
        var value = page(1)
        value.colorMode = .grayscale
        let pages = CompositeLayoutPolicy.workingPages(
            from: [value], paperPreset: .a4, paperOrientation: .portrait, customWidthMM: 210,
            customHeightMM: 297, paperUnit: .millimeter)
        #expect(pages[0].a4WidthRatio == 0.40)
    }

    @Test func savedPlacementPreservesGeometry() {
        var value = page(1)
        value.outputStyle = .a4Centered
        value.a4WidthRatio = 2.25
        value.placementOffsetX = 0.4
        value.placementOffsetY = -0.3
        value.placementRotationDegrees = 37
        let pages = CompositeLayoutPolicy.workingPages(
            from: [value], paperPreset: .b5, paperOrientation: .landscape, customWidthMM: 176,
            customHeightMM: 250, paperUnit: .centimeter)
        #expect(pages[0].a4WidthRatio == 2.25)
        #expect(pages[0].placementOffsetX == 0.4)
        #expect(pages[0].placementOffsetY == -0.3)
        #expect(pages[0].placementRotationDegrees == 37)
    }

    @Test func paperConfigurationAppliesToEveryPageWithoutChangingIdentityOrImageData() {
        let original = [page(1), page(2)]
        let result = CompositeLayoutPolicy.applyingPaper(
            to: original, paperPreset: .custom, paperOrientation: .landscape, customWidthMM: 333,
            customHeightMM: 444, paperUnit: .inch)
        #expect(result.map(\.id) == original.map(\.id))
        #expect(result.map(\.originalData) == original.map(\.originalData))
        #expect(result.allSatisfy { $0.outputStyle == .a4Centered })
        #expect(result.allSatisfy { $0.paperPreset == .custom && $0.paperOrientation == .landscape })
        #expect(result.allSatisfy { $0.customPaperWidthMM == 333 && $0.customPaperHeightMM == 444 })
        #expect(result.allSatisfy { $0.paperUnit == .inch })
    }

    @Test func visibilityToggleChangesOnlyRequestedPage() {
        let first = page(1)
        let second = page(2)
        let result = CompositeLayoutPolicy.togglingVisibility(in: [first, second], id: second.id)
        #expect(result[0].isHiddenFromPreviewAndOutput == false)
        #expect(result[1].isHiddenFromPreviewAndOutput)
        #expect(CompositeLayoutPolicy.togglingVisibility(in: result, id: second.id) == [first, second])
    }

    @Test func missingVisibilityIDMakesNoChange() {
        let values = [page(1), page(2)]
        #expect(CompositeLayoutPolicy.togglingVisibility(in: values, id: UUID()) == values)
    }

    @Test func layerMoveUsesBackToFrontArrayOrder() {
        let back = page(1)
        let middle = page(2)
        let front = page(3)
        let movedForward = CompositeLayoutPolicy.moving([back, middle, front], from: 0, to: 2)
        #expect(movedForward.map(\.id) == [middle.id, front.id, back.id])
        let movedBackward = CompositeLayoutPolicy.moving(movedForward, from: 2, to: 0)
        #expect(movedBackward.map(\.id) == [back.id, middle.id, front.id])
    }

    @Test func layerMoveClampsDestinationAndPreservesPageValues() {
        let first = page(1)
        let second = page(2)
        let third = page(3)
        let result = CompositeLayoutPolicy.moving([first, second, third], from: 0, to: 99)
        #expect(result == [second, third, first])
    }

    @Test func invalidLayerSourceMakesNoChange() {
        let values = [page(1), page(2)]
        #expect(CompositeLayoutPolicy.moving(values, from: -1, to: 0) == values)
        #expect(CompositeLayoutPolicy.moving(values, from: 9, to: 0) == values)
    }

    private func page(_ byte: UInt8) -> ProjectPage {
        ProjectPage(originalData: Data([byte]), renderedData: Data([byte]))
    }
}
