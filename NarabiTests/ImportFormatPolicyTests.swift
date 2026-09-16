import Foundation
import PDFKit
import Testing
import UIKit

@testable import Narabi

@MainActor
struct ImportFormatPolicyTests {
    private func imageData() throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 8))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 8))
        }
        return try #require(image.pngData())
    }

    @Test func normalizesExtensionWithoutChangingPageizableFacts() {
        let result = ImportFormatPolicy.classify(
            url: URL(fileURLWithPath: "/tmp/sample.DOCX"),
            data: Data()
        )
        #expect(result.normalizedExtension == "docx")
        #expect(result.canPageize)
        #expect(result.isOfficePreviewCandidate)
        #expect(result.isPDF == false)
        #expect(result.isImage == false)
    }

    @Test func pdfFactUsesDeclaredType() {
        let result = ImportFormatPolicy.classify(
            url: URL(fileURLWithPath: "/tmp/sample.PDF"),
            data: Data()
        )
        #expect(result.normalizedExtension == "pdf")
        #expect(result.isPDF)
        #expect(result.canPageize == false)
        #expect(result.isOfficePreviewCandidate == false)
    }

    @Test func declaredImageIsRecognizedEvenWhenDataIsInvalid() {
        let result = ImportFormatPolicy.classify(
            url: URL(fileURLWithPath: "/tmp/sample.PNG"),
            data: Data([0, 1, 2])
        )
        #expect(result.isDeclaredImage)
        #expect(result.isDecodableImage == false)
        #expect(result.isImage)
    }

    @Test func decodableImageIsRecognizedWithUnknownExtension() throws {
        let result = ImportFormatPolicy.classify(
            url: URL(fileURLWithPath: "/tmp/sample.unknown"),
            data: try imageData()
        )
        #expect(result.isDeclaredImage == false)
        #expect(result.isDecodableImage)
        #expect(result.isImage)
    }

    @Test func quickLookOnlyFormatsRemainPreviewCandidatesOnly() {
        for ext in ["doc", "xls", "ppt", "pages", "numbers", "key"] {
            let result = ImportFormatPolicy.classify(
                url: URL(fileURLWithPath: "/tmp/sample.\(ext)"),
                data: Data()
            )
            #expect(result.canPageize == false)
            #expect(result.isOfficePreviewCandidate)
            #expect(result.isPDF == false)
            #expect(result.isImage == false)
        }
    }

    @Test func unsupportedFormatHasNoRoutingFacts() {
        let result = ImportFormatPolicy.classify(
            url: URL(fileURLWithPath: "/tmp/sample.bin"),
            data: Data([0, 1, 2])
        )
        #expect(result.canPageize == false)
        #expect(result.isOfficePreviewCandidate == false)
        #expect(result.isPDF == false)
        #expect(result.isImage == false)
    }

    @Test func classificationDoesNotEncodeCallerRoutingOrder() throws {
        let imageWithDocumentExtension = ImportFormatPolicy.classify(
            url: URL(fileURLWithPath: "/tmp/sample.txt"),
            data: try imageData()
        )
        #expect(imageWithDocumentExtension.canPageize)
        #expect(imageWithDocumentExtension.isDecodableImage)
        #expect(imageWithDocumentExtension.isOfficePreviewCandidate)
    }
}
