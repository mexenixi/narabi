import CoreGraphics
import Foundation
import Testing
@testable import Narabi

@Suite("Page render geometry")
struct PageRenderGeometryTests {
    @Test func centeredA4UsesConfiguredPaper() {
        var page = samplePage()
        page.outputStyle = .a4Centered
        page.paperPreset = .a4
        page.paperOrientation = .landscape
        let choice = PageRenderGeometry.paperChoice(for: page, baseImageSize: CGSize(width: 100, height: 200))
        #expect(choice.preset == .a4)
        #expect(choice.orientation == .landscape)
        #expect(choice.widthMM == 297)
        #expect(choice.heightMM == 210)
    }

    @Test func trustedPhysicalSizeMatchesKnownPaper() {
        var page = samplePage()
        page.hasTrustedPhysicalSize = true
        page.sourcePhysicalWidthMM = 210
        page.sourcePhysicalHeightMM = 297
        let choice = PageRenderGeometry.paperChoice(for: page, baseImageSize: CGSize(width: 1, height: 1))
        #expect(choice.preset == .a4)
        #expect(choice.orientation == .portrait)
    }

    @Test func unknownWideImagePreservesWideDimensions() {
        let choice = PageRenderGeometry.paperChoice(
            for: samplePage(), baseImageSize: CGSize(width: 400, height: 200))
        #expect(choice.preset == .custom)
        #expect(choice.orientation == .portrait)
        #expect(abs(choice.widthMM - 300) < 0.000_001)
        #expect(abs(choice.heightMM - 150) < 0.000_001)
        #expect(choice.widthMM > choice.heightMM)
    }

    @Test func unknownPortraitUsesThreeHundredMillimeterLongEdge() {
        let choice = PageRenderGeometry.paperChoice(
            for: samplePage(), baseImageSize: CGSize(width: 100, height: 200))
        #expect(choice.preset == .custom)
        #expect(choice.orientation == .portrait)
        #expect(abs(choice.widthMM - 150) < 0.000_001)
        #expect(abs(choice.heightMM - 300) < 0.000_001)
    }

    @Test func matchedPaperFallsBackToCustomWhenMatchingIsDisabled() {
        let choice = PageRenderGeometry.matchedPaper(
            widthMM: 210, heightMM: 297, unit: .millimeter, allowPresetMatch: false)
        #expect(choice.preset == .custom)
        #expect(choice.widthMM == 210)
        #expect(choice.heightMM == 297)
    }

    @Test func matchedPaperClampsInvalidDimensions() {
        let choice = PageRenderGeometry.matchedPaper(
            widthMM: -10, heightMM: 0, unit: .millimeter, allowPresetMatch: false)
        #expect(choice.widthMM == 1)
        #expect(choice.heightMM == 1)
    }

    @Test func originalRasterLayoutAppliesCrop() {
        var page = samplePage()
        page.cropInsets = PageCropInsets(left: 0.1, right: 0.2, top: 0.25, bottom: 0.25)
        let layout = PageRenderGeometry.rasterLayout(
            for: page,
            baseImageSize: CGSize(width: 1000, height: 500),
            canvasSize: CGSize(width: 700, height: 250))
        #expect(layout.canvasSize == CGSize(width: 700, height: 250))
        #expect(layout.visibleImageRect.width == 700)
        #expect(layout.visibleImageRect.height == 250)
        #expect(layout.fullImageRect.width == 1000)
        #expect(layout.fullImageRect.height == 500)
    }

    @Test func centeredRasterLayoutUsesPlacementAndCrop() {
        var page = samplePage()
        page.outputStyle = .a4Centered
        page.a4WidthRatio = 0.5
        page.placementOffsetX = 0.2
        page.placementOffsetY = -0.2
        page.cropInsets = PageCropInsets(left: 0.1, right: 0.1, top: 0.1, bottom: 0.1)
        let layout = PageRenderGeometry.rasterLayout(
            for: page,
            baseImageSize: CGSize(width: 1000, height: 500),
            canvasSize: CGSize(width: 600, height: 800))
        #expect(layout.fullImageRect.width == 300)
        #expect(layout.fullImageRect.height == 150)
        #expect(layout.visibleImageRect.width == 240)
        #expect(layout.visibleImageRect.height == 120)
    }

    @Test func originalPixelCanvasNeverUpscalesSource() {
        let size = PageRenderGeometry.pixelCanvas(
            for: samplePage(), baseImageSize: CGSize(width: 800, height: 400), maximumLongEdge: 4096)
        #expect(size == CGSize(width: 800, height: 400))
    }

    @Test func originalPixelCanvasHonorsMaximumLongEdge() {
        let size = PageRenderGeometry.pixelCanvas(
            for: samplePage(), baseImageSize: CGSize(width: 4000, height: 2000), maximumLongEdge: 1000)
        #expect(size == CGSize(width: 1000, height: 500))
    }

    @Test func originalPixelCanvasAccountsForCrop() {
        var page = samplePage()
        page.cropInsets = PageCropInsets(left: 0.25, right: 0.25, top: 0, bottom: 0)
        let size = PageRenderGeometry.pixelCanvas(
            for: page, baseImageSize: CGSize(width: 1000, height: 500), maximumLongEdge: 1000)
        #expect(size == CGSize(width: 500, height: 500))
    }

    @Test func paperPixelCanvasUsesPaperAspectRatio() {
        var page = samplePage()
        page.outputStyle = .a4Centered
        page.paperPreset = .a4
        page.paperOrientation = .portrait
        let size = PageRenderGeometry.pixelCanvas(
            for: page, baseImageSize: CGSize(width: 4000, height: 3000), maximumLongEdge: 1000)
        #expect(size.height == 1000)
        #expect(size.width == 707)
    }

    private func samplePage() -> ProjectPage {
        ProjectPage(originalData: Data([1]), renderedData: Data([1]))
    }
}
