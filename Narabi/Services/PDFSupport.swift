import PDFKit
import SwiftUI
import UIKit

struct PDFPreviewView: View {
    let data: Data

    var body: some View {
        PDFRepresentable(data: data)
            .ignoresSafeArea()
    }
}

private struct PDFRepresentable: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}

struct PDFBuilder {
    // 72ポイント = 1インチ。210 x 297 mmの縦A4。
    private static let a4PageSize = CGSize(
        width: 595.2756,
        height: 841.8898
    )

    static func makeOptimized(
        pages: [ProjectPage],
        colorPolicy: ExportColorPolicy = .perPage,
        progress: @escaping @MainActor (Int, Int) -> Void
    ) async throws -> Data? {
        let visible = pages.filter { !$0.isHiddenFromPreviewAndOutput }
        guard !visible.isEmpty else { return nil }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "NarabiPDFStage_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var staged: [(url: URL, size: CGSize)] = []
        staged.reserveCapacity(visible.count)
        for (index, item) in visible.enumerated() {
            try Task.checkCancellation()
            guard
                let image = PageRenderer.render(
                    page: item, maximumLongEdge: 1600, background: .white, colorPolicy: colorPolicy)
            else { continue }
            let baseQuality: CGFloat = item.colorMode == .monochrome ? 0.68 : 0.72
            var quality = baseQuality
            guard var encoded = image.jpegData(compressionQuality: quality) else { continue }
            let oversizedThreshold = 300_000
            if encoded.count > oversizedThreshold {
                quality = max(baseQuality - 0.04, 0.64)
                if let smaller = image.jpegData(compressionQuality: quality) { encoded = smaller }
            }
            let url = directory.appendingPathComponent(String(format: "%04d.jpg", index + 1))
            try encoded.write(to: url, options: .atomic)
            staged.append((url, image.size))
            progress(index + 1, visible.count)
            await Task.yield()
        }
        try Task.checkCancellation()
        guard !staged.isEmpty else { return nil }
        let firstSize = staged[0].size
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: firstSize))
        let data = renderer.pdfData { context in
            for page in staged {
                autoreleasepool {
                    context.beginPage(withBounds: CGRect(origin: .zero, size: page.size), pageInfo: [:])
                    if let image = UIImage(contentsOfFile: page.url.path) {
                        image.draw(in: CGRect(origin: .zero, size: page.size))
                    }
                }
            }
        }
        return data
    }

    static func make(pages: [ProjectPage], colorPolicy: ExportColorPolicy = .perPage) -> Data? {
        let visible = pages.filter { !$0.isHiddenFromPreviewAndOutput }
        guard !visible.isEmpty else { return nil }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: a4PageSize))
        return renderer.pdfData { context in
            for item in visible {
                autoreleasepool {
                    guard
                        let image = PageRenderer.render(
                            page: item,
                            maximumLongEdge: 2400,
                            background: .white,
                            colorPolicy: colorPolicy
                        )
                    else { return }
                    let bounds = CGRect(origin: .zero, size: image.size)
                    context.beginPage(withBounds: bounds, pageInfo: [:])
                    image.draw(in: bounds)

                }
            }
        }
    }

}
