import CoreImage
import Foundation
import UIKit
import Vision

struct AIOCRPageResult {
    let pageID: String
    let position: Int
    let text: String
    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

enum AIOCRService {
    static func recognize(
        pages: [ProjectPage], corrected: Bool,
        progress: @escaping @MainActor (Int, Int) -> Void
    ) async throws -> [AIOCRPageResult] {
        var result: [AIOCRPageResult] = []
        for (index, page) in pages.enumerated() {
            try Task.checkCancellation()
            progress(index, pages.count)
            await Task.yield()
            autoreleasepool {
                // Keep only one decoded page alive. Orientation is normalized by UIImage draw.
            }
            guard let image = PageImagePipeline.displayedImage(for: page) ?? UIImage(data: page.originalData),
                let cg = preparedCGImage(image, corrected: corrected)
            else {
                result.append(
                    .init(pageID: String(format: "P%03d", index + 1), position: index + 1, text: ""))
                continue
            }
            let text = try await recognize(cg)
            result.append(.init(pageID: String(format: "P%03d", index + 1), position: index + 1, text: text))
            progress(index + 1, pages.count)
            await Task.yield()
        }
        progress(pages.count, pages.count)
        await Task.yield()
        return result
    }

    private static func preparedCGImage(_ image: UIImage, corrected: Bool) -> CGImage? {
        let normalized = image.normalizedForNarabi()
        guard corrected else { return normalized.cgImage }
        // Automatic perspective correction is best effort. If rectangle detection fails, use normalized image.
        guard let cg = normalized.cgImage else { return nil }
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.55
        request.minimumSize = 0.20
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])
        guard let rect = request.results?.first else { return cg }
        let ci = CIImage(cgImage: cg)
        let w = ci.extent.width
        let h = ci.extent.height
        func p(_ q: CGPoint) -> CIVector { CIVector(x: q.x * w, y: q.y * h) }
        guard let f = CIFilter(name: "CIPerspectiveCorrection") else { return cg }
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(p(rect.topLeft), forKey: "inputTopLeft")
        f.setValue(p(rect.topRight), forKey: "inputTopRight")
        f.setValue(p(rect.bottomLeft), forKey: "inputBottomLeft")
        f.setValue(p(rect.bottomRight), forKey: "inputBottomRight")
        guard let output = f.outputImage else { return cg }
        return CIContext(options: [.useSoftwareRenderer: false]).createCGImage(output, from: output.extent)
            ?? cg
    }

    private static func recognize(_ image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let lines =
                    (request.results as? [VNRecognizedTextObservation])?.compactMap {
                        $0.topCandidates(1).first?.string
                    } ?? []
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            request.recognitionLanguages = Array(
                Set([Locale.preferredLanguages.first ?? "en", "ja-JP", "en-US"]))
            do { try VNImageRequestHandler(cgImage: image, options: [:]).perform([request]) } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static func package(session: String, prompt: String, results: [AIOCRPageResult]) -> Data {
        var s = "NARABI AI SORT PACKAGE\nMODE: OCR_TEXT\nSESSION: \(session)\n\nUSER_PROMPT:\n\(prompt)\n\n"
        for r in results {
            s +=
                "PAGE_BEGIN\nPAGE_ID: \(r.pageID)\nCURRENT_POSITION: \(r.position)\nOCR_STATUS: \(r.isEmpty ? "NO_TEXT_FOUND" : "SUCCESS")\nOCR_TEXT:\n\(r.text)\nPAGE_END\n\n"
        }
        s += "RETURN_FORMAT:\nSESSION:{ID}|ORDER:{PAGE_ID list}|REASON:{short reason}\n"
        return Data(s.utf8)
    }
}

private extension UIImage {
    func normalizedForNarabi() -> UIImage {
        if imageOrientation == .up { return self }
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        f.opaque = false
        return UIGraphicsImageRenderer(size: size, format: f).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
