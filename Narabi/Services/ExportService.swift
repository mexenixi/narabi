import Foundation
import Photos
import UIKit

struct ExportProgress: Equatable {
    var completed = 0
    var total = 0
    var message = ""
}

struct NormalImageExportResult {
    let urls: [URL]
    let directory: URL
}

nonisolated enum ExportService {
    static func safeFileBaseName(_ requestedName: String) -> String {
        let trimmed = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        var invalid = CharacterSet(charactersIn: "/:")
        invalid.insert(charactersIn: Unicode.Scalar(92)!...Unicode.Scalar(92)!)
        invalid.formUnion(.newlines)
        invalid.formUnion(.controlCharacters)
        return
            trimmed
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func resized(_ image: UIImage, longEdge: ExportLongEdge) -> UIImage {
        guard longEdge.rawValue > 0 else { return PageImagePipeline.normalizedOrientation(image) }
        return PageImagePipeline.resizedPreservingContent(
            image,
            maximumLongEdge: CGFloat(longEdge.rawValue)
        )
    }

    static func workspaceThumbnail(for page: ProjectPage, maximumPixel: CGFloat = 720) -> UIImage? {
        PageRenderer.render(page: page, maximumLongEdge: maximumPixel, background: .white)
    }

    static func compositeImage(
        pages: [ProjectPage], transparent: Bool, longEdge: ExportLongEdge,
        colorPolicy: ExportColorPolicy, customPixelSize: CGSize? = nil
    ) -> UIImage? {
        guard let first = pages.first, let base = PageImagePipeline.baseImage(for: first) else { return nil }
        let edge =
            longEdge.rawValue > 0 ? CGFloat(longEdge.rawValue) : max(base.size.width, base.size.height, 1)
        let canvas =
            customPixelSize.map {
                CGSize(width: max(1, floor($0.width)), height: max(1, floor($0.height)))
            }
            ?? PageRenderGeometry.pixelCanvas(
                for: first, baseImageSize: base.size, maximumLongEdge: edge)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !transparent
        return UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            let bounds = CGRect(origin: .zero, size: canvas)
            if !transparent {
                UIColor.white.setFill()
                context.fill(bounds)
            }
            for page in pages where !page.isHiddenFromPreviewAndOutput {
                autoreleasepool {
                    guard
                        let layer = PageRenderer.render(
                            page: page, maximumLongEdge: edge, background: .transparent,
                            colorPolicy: colorPolicy, exactPixelSize: canvas)
                    else { return }
                    layer.draw(in: bounds)
                }
            }
        }
    }

    static func compositePDFData(_ image: UIImage) -> Data {
        let bounds = CGRect(origin: .zero, size: image.size)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { c in
            c.beginPage()
            UIColor.white.setFill()
            c.fill(bounds)
            image.draw(in: bounds)
        }
    }

    static func saveCompositeToPhotos(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "PhotoPermission", code: 1)
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    static func encodedData(
        _ image: UIImage, preset: ExportPreset, mode: ProjectPage.ColorMode, jpegQuality: Double
    ) -> Data? {
        if preset == .png || preset == .transparentPNG { return image.pngData() }
        let quality: Double
        switch mode {
        case .color: quality = jpegQuality
        case .grayscale: quality = min(jpegQuality, 0.82)
        case .monochrome: quality = min(jpegQuality, 0.72)
        }
        if mode == .color {
            return PageImagePipeline.opaqueImage(image).jpegData(compressionQuality: quality)
        }
        let gray = grayscaleBitmap(image) ?? image
        return gray.jpegData(compressionQuality: quality)
    }

    static func grayscaleBitmap(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let width = cg.width
        let height = cg.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let output = context.makeImage() else { return nil }
        return UIImage(cgImage: output, scale: 1, orientation: .up)
    }

    static func imageFiles(
        pages: [ProjectPage],
        preset: ExportPreset,
        longEdge: ExportLongEdge,
        jpegQuality: Double,
        colorPolicy: ExportColorPolicy,
        customPixelSize: CGSize? = nil,
        baseName: String,
        progress: @escaping (ExportProgress) -> Void
    ) async throws -> NormalImageExportResult {
        let visible = pages.filter { !$0.isHiddenFromPreviewAndOutput }
        guard !visible.isEmpty else { throw CocoaError(.fileWriteUnknown) }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NarabiImageExport-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var completedSuccessfully = false
        defer {
            if !completedSuccessfully { try? FileManager.default.removeItem(at: directory) }
        }

        var urls: [URL] = []
        for (index, page) in visible.enumerated() {
            try Task.checkCancellation()
            let edge = CGFloat(longEdge.rawValue)
            let background: PageRenderer.Background = preset == .transparentPNG ? .transparent : .white
            guard
                let image = autoreleasepool(invoking: {
                    PageRenderer.render(
                        page: page, maximumLongEdge: edge, background: background, colorPolicy: colorPolicy,
                        exactPixelSize: customPixelSize)
                })
            else { throw CocoaError(.fileWriteUnknown) }

            let mode = PageColorRenderer.resolvedMode(pageMode: page.colorMode, policy: colorPolicy)
            guard
                let data = autoreleasepool(invoking: {
                    encodedData(image, preset: preset, mode: mode, jpegQuality: jpegQuality)
                }), !data.isEmpty
            else { throw CocoaError(.fileWriteUnknown) }

            let ext = (preset == .png || preset == .transparentPNG) ? "png" : "jpg"
            let url = directory.appendingPathComponent(String(format: "%@_%04d.%@", baseName, index + 1, ext))
            try data.write(to: url, options: .atomic)
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true, (values.fileSize ?? 0) > 0 else {
                throw CocoaError(.fileWriteUnknown)
            }
            urls.append(url)
            progress(
                ExportProgress(
                    completed: index + 1, total: visible.count, message: "\(index + 1) / \(visible.count)"))
            await Task.yield()
        }
        try Task.checkCancellation()
        guard urls.count == visible.count else { throw CocoaError(.fileWriteUnknown) }
        completedSuccessfully = true
        return NormalImageExportResult(urls: urls, directory: directory)
    }

    static func saveToPhotos(
        pages: [ProjectPage], longEdge: ExportLongEdge, colorPolicy: ExportColorPolicy,
        progress: @escaping (ExportProgress) -> Void
    ) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "PhotoPermission", code: 1)
        }
        let visiblePages = pages.filter { !$0.isHiddenFromPreviewAndOutput }
        for (index, page) in visiblePages.enumerated() {
            if Task.isCancelled { return }
            let edge = CGFloat(longEdge.rawValue)
            guard
                let image = PageRenderer.render(
                    page: page,
                    maximumLongEdge: edge,
                    background: .white,
                    colorPolicy: colorPolicy
                )
            else { continue }
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }

            progress(
                ExportProgress(
                    completed: index + 1, total: visiblePages.count,
                    message: "\(index + 1) / \(visiblePages.count)"))
            await Task.yield()
        }
    }
}
