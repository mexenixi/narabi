import Foundation
import Testing

@testable import Narabi

struct PageEditResultPolicyTests {
    private func originalPage() -> ProjectPage {
        ProjectPage(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            originalData: Data([1, 2, 3]),
            renderedData: Data([4, 5]),
            editBaseData: Data([6]),
            outputStyle: .original,
            a4WidthRatio: 0.41,
            paperPreset: .a4,
            paperOrientation: .portrait,
            customPaperWidthMM: 210,
            customPaperHeightMM: 297,
            paperUnit: .millimeter,
            placementOffsetX: 0.1,
            placementOffsetY: -0.2,
            placementRotationDegrees: 5,
            colorMode: .color,
            isHiddenFromPreviewAndOutput: true,
            cropInsets: PageCropInsets(left: 0.01, right: 0.02, top: 0.03, bottom: 0.04),
            placementBaseWidthMM: 123,
            sourceKind: .pdf,
            sourcePixelWidth: 1200,
            sourcePixelHeight: 1800,
            sourcePhysicalWidthMM: 210,
            sourcePhysicalHeightMM: 297,
            hasTrustedPhysicalSize: true
        )
    }

    private func settings() -> PageEditResultPolicy.Settings {
        .init(
            outputStyle: .a4Centered,
            a4WidthRatio: 0.72,
            paperPreset: .letter,
            paperOrientation: .landscape,
            customPaperWidthMM: 321,
            customPaperHeightMM: 654,
            paperUnit: .inch,
            placementOffsetX: -0.45,
            placementOffsetY: 0.35,
            placementRotationDegrees: 87,
            colorMode: .monochrome,
            cropInsets: PageCropInsets(left: 0.1, right: 0.2, top: 0.15, bottom: 0.25)
        )
    }

    @Test func appliesTheSameEditedDataToBothEditingRepresentations() {
        let data = Data([9, 8, 7])
        let result = PageEditResultPolicy.applying(to: originalPage(), editedData: data, settings: settings())
        #expect(result.editBaseData == data)
        #expect(result.renderedData == data)
    }

    @Test func appliesOutputAndPaperSettings() {
        let result = PageEditResultPolicy.applying(
            to: originalPage(), editedData: Data([9]), settings: settings())
        #expect(result.outputStyle == .a4Centered)
        #expect(result.a4WidthRatio == 0.72)
        #expect(result.paperPreset == .letter)
        #expect(result.paperOrientation == .landscape)
        #expect(result.customPaperWidthMM == 321)
        #expect(result.customPaperHeightMM == 654)
        #expect(result.paperUnit == .inch)
    }

    @Test func appliesPlacementSettings() {
        let result = PageEditResultPolicy.applying(
            to: originalPage(), editedData: Data([9]), settings: settings())
        #expect(result.placementOffsetX == -0.45)
        #expect(result.placementOffsetY == 0.35)
        #expect(result.placementRotationDegrees == 87)
    }

    @Test func appliesColorAndCropSettings() {
        let result = PageEditResultPolicy.applying(
            to: originalPage(), editedData: Data([9]), settings: settings())
        #expect(result.colorMode == .monochrome)
        #expect(result.cropInsets == PageCropInsets(left: 0.1, right: 0.2, top: 0.15, bottom: 0.25))
    }

    @Test func preservesIdentityAndOriginalData() {
        let original = originalPage()
        let result = PageEditResultPolicy.applying(to: original, editedData: Data([9]), settings: settings())
        #expect(result.id == original.id)
        #expect(result.originalData == original.originalData)
    }

    @Test func preservesVisibilityAndPlacementBaseWidth() {
        let original = originalPage()
        let result = PageEditResultPolicy.applying(to: original, editedData: Data([9]), settings: settings())
        #expect(result.isHiddenFromPreviewAndOutput == original.isHiddenFromPreviewAndOutput)
        #expect(result.placementBaseWidthMM == original.placementBaseWidthMM)
    }

    @Test func preservesSourcePixelAndPhysicalMetadata() {
        let original = originalPage()
        let result = PageEditResultPolicy.applying(to: original, editedData: Data([9]), settings: settings())
        #expect(result.sourceKind == original.sourceKind)
        #expect(result.sourcePixelWidth == original.sourcePixelWidth)
        #expect(result.sourcePixelHeight == original.sourcePixelHeight)
        #expect(result.sourcePhysicalWidthMM == original.sourcePhysicalWidthMM)
        #expect(result.sourcePhysicalHeightMM == original.sourcePhysicalHeightMM)
        #expect(result.hasTrustedPhysicalSize == original.hasTrustedPhysicalSize)
    }

    @Test func doesNotMutateTheOriginalValue() {
        let original = originalPage()
        _ = PageEditResultPolicy.applying(to: original, editedData: Data([9]), settings: settings())
        #expect(original.renderedData == Data([4, 5]))
        #expect(original.editBaseData == Data([6]))
        #expect(original.outputStyle == .original)
    }
}
