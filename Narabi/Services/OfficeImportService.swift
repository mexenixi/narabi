import Foundation
import QuickLookThumbnailing
import UIKit

enum OfficeImportService {
    nonisolated static let extensions: Set<String> = [
        "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "txt", "text", "md", "markdown", "csv", "tsv", "log", "json",
        "xml", "html", "htm", "yaml", "yml", "ics",
        "pages", "numbers", "key",
    ]

    static func previewPage(for url: URL) async -> UIImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 1400, height: 1800),
            scale: 1,
            representationTypes: .all
        )
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
                continuation.resume(returning: thumbnail?.uiImage)
            }
        }
    }
}
