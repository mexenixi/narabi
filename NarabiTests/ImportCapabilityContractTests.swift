import Foundation
import PDFKit
import Testing
@testable import Narabi

@Suite("Import capability contracts")
struct ImportCapabilityContractTests {
    @Test func pageizableExtensionsAreCaseInsensitive() {
        #expect(DocumentPageImportService.canPageize(URL(fileURLWithPath: "/tmp/sample.DOCX")))
        #expect(DocumentPageImportService.canPageize(URL(fileURLWithPath: "/tmp/sample.XLSX")))
        #expect(DocumentPageImportService.canPageize(URL(fileURLWithPath: "/tmp/sample.PPTX")))
        #expect(DocumentPageImportService.canPageize(URL(fileURLWithPath: "/tmp/sample.JSON")))
        #expect(DocumentPageImportService.canPageize(URL(fileURLWithPath: "/tmp/sample.ICS")))
    }

    @Test func unsupportedOrMissingExtensionsAreRejected() {
        #expect(!DocumentPageImportService.canPageize(URL(fileURLWithPath: "/tmp/sample.rtf")))
        #expect(!DocumentPageImportService.canPageize(URL(fileURLWithPath: "/tmp/sample.plist")))
        #expect(!DocumentPageImportService.canPageize(URL(fileURLWithPath: "/tmp/no-extension")))
    }

    @MainActor @Test func estimatedCountUsesOnePerImage() {
        let items = [
            ImportItem(kind: .image, data: Data([1]), displayName: "one"),
            ImportItem(kind: .image, data: Data([2]), displayName: "two"),
        ]
        #expect(NewProjectCreationService.estimatedPageCount(for: items) == 2)
    }

    @MainActor @Test func invalidPDFStillContributesOneEstimatedPage() {
        let item = ImportItem(kind: .pdf, data: Data([0, 1, 2]), displayName: "invalid")
        #expect(NewProjectCreationService.estimatedPageCount(for: [item]) == 1)
    }

    @MainActor @Test func validPDFUsesItsActualPageCount() throws {
        let document = PDFDocument()
        let firstPage = try #require(PDFPage(image: solidImage()))
        let secondPage = try #require(PDFPage(image: solidImage()))
        document.insert(firstPage, at: 0)
        document.insert(secondPage, at: 1)
        let item = ImportItem(kind: .pdf, data: document.dataRepresentation() ?? Data(), displayName: "two")
        #expect(NewProjectCreationService.estimatedPageCount(for: [item]) == 2)
    }

    @MainActor private func solidImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
}
