import Foundation
import UIKit
import UniformTypeIdentifiers

nonisolated enum ImportFormatPolicy {
    struct Classification: Equatable {
        let normalizedExtension: String
        let isPDF: Bool
        let isDeclaredImage: Bool
        let isDecodableImage: Bool
        let canPageize: Bool
        let isOfficePreviewCandidate: Bool

        var isImage: Bool {
            isDeclaredImage || isDecodableImage
        }
    }

    static func classify(url: URL, data: Data) -> Classification {
        let normalizedExtension = url.pathExtension.lowercased()
        let contentType = UTType(filenameExtension: url.pathExtension)
        return Classification(
            normalizedExtension: normalizedExtension,
            isPDF: contentType?.conforms(to: .pdf) == true,
            isDeclaredImage: contentType?.conforms(to: .image) == true,
            isDecodableImage: UIImage(data: data) != nil,
            canPageize: DocumentPageImportService.canPageize(url),
            isOfficePreviewCandidate: OfficeImportService.extensions.contains(normalizedExtension)
        )
    }
}
