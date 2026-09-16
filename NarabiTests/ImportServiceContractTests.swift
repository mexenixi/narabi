import PDFKit
import Testing
import UIKit

@testable import Narabi

@MainActor
struct ImportServiceContractTests {
    private func image(width: CGFloat = 40, height: CGFloat = 20) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.black.setFill()
            context.fill(CGRect(x: 4, y: 4, width: width / 2, height: height / 2))
        }
    }

    private func imageItem(name: String = "image.png") throws -> ImportItem {
        let data = try #require(image().pngData())
        return ImportItem(kind: .image, data: data, displayName: name)
    }

    private func pdfItem(pageCount: Int = 2) throws -> ImportItem {
        let document = PDFDocument()
        for index in 0..<pageCount {
            let pageImage = image(width: CGFloat(40 + index), height: CGFloat(20 + index))
            let page = try #require(PDFPage(image: pageImage))
            document.insert(page, at: index)
        }
        let data = try #require(document.dataRepresentation())
        return ImportItem(kind: .pdf, data: data, displayName: "document.pdf")
    }

    @Test func progressBeginUsesSafeMinimumsAndResetsValues() {
        let state = ImportProgressState()
        state.currentFile = 8
        state.currentUnit = 9
        state.generatedPages = 7
        state.cancellationRequested = true
        state.allowsCancellation = false

        state.begin(totalFiles: 0)

        #expect(state.isPresented)
        #expect(state.totalFiles == 1)
        #expect(state.currentFile == 0)
        #expect(state.currentUnit == 0)
        #expect(state.totalUnits == 0)
        #expect(state.generatedPages == 0)
        #expect(state.cancellationRequested == false)
        #expect(state.allowsCancellation)
    }

    @Test func projectPreparationClampsProgressAndDisablesCancellation() {
        let state = ImportProgressState()
        state.beginProjectPreparation(totalItems: 0, totalPages: 0)
        state.updateProjectPreparation(item: 4, completedPages: 5)

        #expect(state.isPresented)
        #expect(state.totalFiles == 1)
        #expect(state.totalUnits == 1)
        #expect(state.currentFile == 1)
        #expect(state.currentUnit == 1)
        #expect(state.generatedPages == 1)
        #expect(state.allowsCancellation == false)

        state.updateProjectPreparation(item: -2, completedPages: -3)
        #expect(state.currentFile == 0)
        #expect(state.currentUnit == 0)
        #expect(state.generatedPages == 0)
    }

    @Test func cancelAndFinishHaveStableStateTransitions() {
        let state = ImportProgressState()
        state.begin(totalFiles: 2)
        state.cancel()
        #expect(state.cancellationRequested)
        #expect(state.isPresented)

        state.finish()
        #expect(state.isPresented == false)
        #expect(state.phase.isEmpty)
        #expect(state.currentFile == 0)
        #expect(state.totalFiles == 0)
        #expect(state.currentUnit == 0)
        #expect(state.totalUnits == 0)
        #expect(state.generatedPages == 0)
        #expect(state.cancellationRequested == false)
        #expect(state.allowsCancellation)
    }

    @Test func pageEstimateCombinesImagesAndPDFPages() throws {
        let items = [try imageItem(), try pdfItem(pageCount: 2)]
        #expect(NewProjectCreationService.estimatedPageCount(for: items) == 3)
        #expect(NewProjectCreationService.estimatedPageCount(for: []) == 0)

        let broken = ImportItem(kind: .pdf, data: Data([0, 1, 2]), displayName: "broken.pdf")
        #expect(NewProjectCreationService.estimatedPageCount(for: [broken]) == 1)
    }

    @Test func imageCreationPreservesSourceMetadataAndProgress() async throws {
        let item = try imageItem()
        var updates: [NewProjectCreationService.Progress] = []
        let result = await NewProjectCreationService.createPages(from: [item]) {
            updates.append($0)
        }

        #expect(result.pages.count == 1)
        #expect(result.inputItemCount == 1)
        #expect(result.successfulItemCount == 1)
        #expect(result.failedItemCount == 0)
        #expect(result.isPartialSuccess == false)
        let page = try #require(result.pages.first)
        #expect(page.sourceKind == .image)
        #expect((page.sourcePixelWidth ?? 0) > 0)
        #expect((page.sourcePixelHeight ?? 0) > 0)
        #expect(page.hasTrustedPhysicalSize == false)
        #expect(updates == [.init(currentItem: 1, completedPages: 1, totalPages: 1)])
    }

    @Test func pdfCreationPreservesOrderPhysicalSizeAndProgress() async throws {
        let item = try pdfItem(pageCount: 2)
        var updates: [NewProjectCreationService.Progress] = []
        let result = await NewProjectCreationService.createPages(from: [item]) {
            updates.append($0)
        }

        #expect(result.pages.count == 2)
        #expect(result.successfulItemCount == 1)
        #expect(result.failedItemCount == 0)
        #expect(result.pages.allSatisfy { $0.sourceKind == .pdf })
        #expect(result.pages.allSatisfy { $0.hasTrustedPhysicalSize })
        #expect(result.pages.allSatisfy { ($0.sourcePhysicalWidthMM ?? 0) > 0 })
        #expect(result.pages.allSatisfy { ($0.sourcePhysicalHeightMM ?? 0) > 0 })
        #expect(updates.map(\.completedPages) == [1, 2])
        #expect(updates.allSatisfy { $0.currentItem == 1 && $0.totalPages == 2 })
    }

    @Test func partialSuccessCountsItemsWithoutLosingValidPages() async throws {
        let valid = try imageItem()
        let broken = ImportItem(kind: .image, data: Data([0, 1, 2]), displayName: "broken.png")
        let result = await NewProjectCreationService.createPages(from: [valid, broken]) { _ in }

        #expect(result.pages.count == 1)
        #expect(result.inputItemCount == 2)
        #expect(result.successfulItemCount == 1)
        #expect(result.failedItemCount == 1)
        #expect(result.isPartialSuccess)
    }

    @Test func completeFailureIsNotReportedAsPartialSuccess() async {
        let brokenImage = ImportItem(kind: .image, data: Data([0]), displayName: "bad.png")
        let brokenPDF = ImportItem(kind: .pdf, data: Data([1]), displayName: "bad.pdf")
        let result = await NewProjectCreationService.createPages(from: [brokenImage, brokenPDF]) { _ in }

        #expect(result.pages.isEmpty)
        #expect(result.successfulItemCount == 0)
        #expect(result.failedItemCount == 2)
        #expect(result.isPartialSuccess == false)
    }

    @Test func scanFiltersPreserveImageDimensions() {
        let source = image(width: 42, height: 24)
        let color = ScanImageProcessor.apply(.color, to: source)
        let grayscale = ScanImageProcessor.apply(.grayscale, to: source)
        let monochrome = ScanImageProcessor.apply(.monochrome, to: source)

        #expect(color === source)
        #expect(grayscale.size == source.size)
        #expect(monochrome.size == source.size)
    }

    @Test func exportColorPolicyResolvesEveryMode() {
        #expect(PageColorRenderer.resolvedMode(pageMode: .monochrome, policy: .perPage) == .monochrome)
        #expect(PageColorRenderer.resolvedMode(pageMode: .grayscale, policy: .allColor) == .color)
        #expect(PageColorRenderer.resolvedMode(pageMode: .color, policy: .allGrayscale) == .grayscale)
        #expect(PageColorRenderer.resolvedMode(pageMode: .color, policy: .allMonochrome) == .monochrome)
    }

    @Test func pageColorRenderingPreservesDimensions() {
        let source = image(width: 46, height: 28)
        let color = PageColorRenderer.render(source, mode: .color)
        let grayscale = PageColorRenderer.render(source, mode: .grayscale)
        let monochrome = PageColorRenderer.render(source, mode: .monochrome)

        #expect(color === source)
        #expect(grayscale.size == source.size)
        #expect(monochrome.size == source.size)
    }
}
