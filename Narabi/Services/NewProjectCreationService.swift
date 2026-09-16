import PDFKit
import UIKit

@MainActor
enum NewProjectCreationService {
    struct CreationResult {
        let pages: [ProjectPage]
        let inputItemCount: Int
        let successfulItemCount: Int
        let failedItemCount: Int

        var isPartialSuccess: Bool { !pages.isEmpty && failedItemCount > 0 }
    }

    struct Progress: Equatable {
        let currentItem: Int
        let completedPages: Int
        let totalPages: Int
    }

    static func estimatedPageCount(for items: [ImportItem]) -> Int {
        items.reduce(into: 0) { count, item in
            switch item.kind {
            case .image:
                count += 1
            case .pdf:
                count += max(PDFDocument(data: item.data)?.pageCount ?? 0, 1)
            }
        }
    }

    static func createPages(
        from items: [ImportItem],
        progress: (Progress) -> Void
    ) async -> CreationResult {
        let totalPages = max(estimatedPageCount(for: items), 1)
        var completedPages = 0
        var pages: [ProjectPage] = []
        var successfulItems = 0
        var failedItems = 0

        for (itemIndex, item) in items.enumerated() {
            let pagesBeforeItem = pages.count
            autoreleasepool {
                switch item.kind {
                case .image:
                    // Animated images intentionally use the first frame as a still image.
                    guard
                        let image = UIImage(data: item.data),
                        let data = PageImagePipeline.workingData(from: image)
                    else { return }
                    pages.append(
                        ProjectPage(
                            originalData: data,
                            renderedData: data,
                            sourceKind: .image,
                            sourcePixelWidth: image.cgImage?.width ?? Int(image.size.width),
                            sourcePixelHeight: image.cgImage?.height ?? Int(image.size.height)
                        ))
                    completedPages += 1
                    progress(
                        Progress(
                            currentItem: itemIndex + 1, completedPages: completedPages, totalPages: totalPages
                        ))

                case .pdf:
                    guard let document = PDFDocument(data: item.data) else { return }
                    for pageIndex in 0..<document.pageCount {
                        autoreleasepool {
                            guard
                                let page = document.page(at: pageIndex),
                                let image = PageImagePipeline.image(for: page),
                                let data = image.jpegData(compressionQuality: 0.82)
                            else { return }
                            pages.append(
                                ProjectPage(
                                    originalData: data,
                                    renderedData: data,
                                    sourceKind: .pdf,
                                    sourcePixelWidth: image.cgImage?.width ?? Int(image.size.width),
                                    sourcePixelHeight: image.cgImage?.height ?? Int(image.size.height),
                                    sourcePhysicalWidthMM: Double(page.bounds(for: .mediaBox).width) * 25.4
                                        / 72.0,
                                    sourcePhysicalHeightMM: Double(page.bounds(for: .mediaBox).height) * 25.4
                                        / 72.0,
                                    hasTrustedPhysicalSize: true
                                ))
                            completedPages += 1
                            progress(
                                Progress(
                                    currentItem: itemIndex + 1, completedPages: completedPages,
                                    totalPages: totalPages))
                        }
                    }
                }
            }
            if pages.count > pagesBeforeItem {
                successfulItems += 1
            } else {
                failedItems += 1
            }
            await Task.yield()
        }
        return CreationResult(
            pages: pages,
            inputItemCount: items.count,
            successfulItemCount: successfulItems,
            failedItemCount: failedItems
        )
    }
}
