import PDFKit
import UIKit

/// Converts imported image and PDF data into the app's working page representation.
/// This type owns CPU-heavy decoding and compression, while EditorView only applies
/// the resulting pages to editor state on MainActor.
nonisolated enum EditorImportPipeline {
    static func page(from image: UIImage) -> ProjectPage? {
        guard let data = PageImagePipeline.workingData(from: image) else {
            return nil
        }
        return ProjectPage(originalData: data, renderedData: data)
    }

    static func page(fromImageData data: Data) -> ProjectPage? {
        // Animated images intentionally use the first frame supplied by UIImage.
        guard let image = UIImage(data: data) else {
            return nil
        }
        return page(from: image)
    }

    static func pages(fromPDFData data: Data) -> [ProjectPage] {
        guard let document = PDFDocument(data: data) else {
            return []
        }

        var pages: [ProjectPage] = []
        pages.reserveCapacity(document.pageCount)
        for index in 0..<document.pageCount {
            autoreleasepool {
                guard let pdfPage = document.page(at: index),
                    let image = PageImagePipeline.image(for: pdfPage),
                    let encoded = PageImagePipeline.workingData(
                        from: image,
                        maximumLongEdge: PageImagePipeline.pdfMaximumLongEdge
                    )
                else {
                    return
                }
                pages.append(
                    ProjectPage(
                        originalData: encoded,
                        renderedData: encoded
                    )
                )
            }
        }
        return pages
    }
    static func pages(
        fromPDFData data: Data,
        progress: @escaping @MainActor (Int, Int) -> Bool
    ) async -> [ProjectPage] {
        guard let document = PDFDocument(data: data) else { return [] }
        let total = document.pageCount
        var pages: [ProjectPage] = []
        pages.reserveCapacity(total)
        for index in 0..<total {
            if await !progress(index, total) { return [] }
            let page = autoreleasepool { () -> ProjectPage? in
                guard let pdfPage = document.page(at: index),
                    let image = PageImagePipeline.image(for: pdfPage),
                    let encoded = PageImagePipeline.workingData(
                        from: image,
                        maximumLongEdge: PageImagePipeline.pdfMaximumLongEdge
                    )
                else { return nil }
                return ProjectPage(originalData: encoded, renderedData: encoded)
            }
            if let page { pages.append(page) }
            if await !progress(index + 1, total) { return [] }
            await Task.yield()
        }
        return pages
    }

}
