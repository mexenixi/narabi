import PDFKit
import Testing
import UIKit
@testable import Narabi

@Suite("PDF generation")
struct PDFSupportTests {
    @Test func returnsNilForNoVisiblePages() {
        #expect(PDFBuilder.make(pages: []) == nil)
        var hidden = page(color: .red)
        hidden.isHiddenFromPreviewAndOutput = true
        #expect(PDFBuilder.make(pages: [hidden]) == nil)
    }

    @Test func createsOnePDFPagePerVisibleInputPage() throws {
        var hidden = page(color: .green)
        hidden.isHiddenFromPreviewAndOutput = true
        let data = try #require(PDFBuilder.make(pages: [page(color: .red), hidden, page(color: .blue)]))
        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 2)
    }

    private func page(color: UIColor) -> ProjectPage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30))
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
        let data = image.pngData()!
        return ProjectPage(originalData: data, renderedData: data)
    }
}
