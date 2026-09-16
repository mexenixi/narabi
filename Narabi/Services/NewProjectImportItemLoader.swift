import Foundation
import UIKit

@MainActor
enum NewProjectImportItemLoader {
    static func load(from url: URL) async throws -> [ImportItem] {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else { return [] }
        let format = ImportFormatPolicy.classify(url: url, data: data)

        if format.canPageize {
            let images: [UIImage]
            do {
                images = try await Task.detached(priority: .userInitiated) {
                    try DocumentPageImportService.pageImages(for: url)
                }.value
            } catch let error as DocumentImportSafetyError {
                throw error
            } catch {
                images = []
            }

            let baseName = url.deletingPathExtension().lastPathComponent
            let items = images.enumerated().compactMap { index, image in
                PageImagePipeline.workingData(from: image).map {
                    ImportItem(
                        kind: .image,
                        data: $0,
                        displayName: "\(baseName) \(index + 1)"
                    )
                }
            }
            if !items.isEmpty { return items }
        }

        if format.isPDF {
            return [ImportItem(kind: .pdf, data: data, displayName: url.lastPathComponent)]
        }

        if format.isImage {
            return [ImportItem(kind: .image, data: data, displayName: url.lastPathComponent)]
        }

        return []
    }
}
