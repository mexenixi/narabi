import Foundation
import UIKit

struct AIPackageResult {
    let url: URL
    let request: ActiveAISortRequest
}

enum AISortPackageService {

    static func request(projectID: UUID, pages: [(index: Int, page: ProjectPage)], prompt: String)
        -> ActiveAISortRequest?
    {
        guard !pages.isEmpty else { return nil }
        let code = String(UUID().uuidString.prefix(6)).uppercased()
        let refs = pages.enumerated().map { offset, value in
            AIPageReference(
                id: String(format: "P%03d", offset + 1), pageID: value.page.id, fixedEditorIndex: value.index)
        }
        return ActiveAISortRequest(
            projectID: projectID, code: code, pages: refs, prompt: prompt,
            originalSelection: pages.map { $0.page.id })
    }

    static func makePDF(
        projectID: UUID, pages: [(index: Int, page: ProjectPage)], prompt: String, includeReason: Bool,
        lightweight: Bool, progress: @escaping @MainActor (Int, Int) -> Void
    ) async throws -> AIPackageResult {
        guard let request = request(projectID: projectID, pages: pages, prompt: prompt) else {
            throw CancellationError()
        }
        let maximumLongEdge: CGFloat = lightweight ? 1100 : 1500
        let jpegQuality: CGFloat = lightweight ? 0.60 : 0.78
        let stageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "NarabiAIPDFStage_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stageDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stageDirectory) }
        var staged: [URL] = []
        staged.reserveCapacity(pages.count)
        for (offset, value) in pages.enumerated() {
            try Task.checkCancellation()
            guard var image = PageImagePipeline.displayedImage(for: value.page) else { continue }
            if lightweight { image = PageColorRenderer.render(image, mode: .grayscale) }
            image = PageImagePipeline.resizedPreservingContent(image, maximumLongEdge: maximumLongEdge)
            guard let encoded = image.jpegData(compressionQuality: jpegQuality) else { continue }
            let url = stageDirectory.appendingPathComponent(String(format: "%04d.jpg", offset + 1))
            try encoded.write(to: url, options: .atomic)
            staged.append(url)
            progress(offset + 1, pages.count)
            await Task.yield()
        }
        try Task.checkCancellation()
        guard staged.count == pages.count else {
            throw NSError(
                domain: "AISortPackage", code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: L10n.text("ai.error.packageCreation", "AI用PDFのページ生成に失敗しました。")
                ])
        }
        let pageSize = CGSize(width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let data = renderer.pdfData { context in
            context.beginPage()
            drawWrapped(
                instructions(code: request.code, prompt: prompt, includeReason: includeReason),
                rect: CGRect(x: 36, y: 35, width: 523, height: 770), font: .systemFont(ofSize: 12))
            for (offset, url) in staged.enumerated() {
                autoreleasepool {
                    context.beginPage()
                    let ref = request.pages[offset]
                    "\(ref.id)  CURRENT: \(pages[offset].index + 1)".draw(
                        at: CGPoint(x: 30, y: 25), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18)])
                    guard let image = UIImage(contentsOfFile: url.path) else { return }
                    let maxRect = CGRect(x: 30, y: 62, width: 535, height: 740)
                    let scale = min(maxRect.width / image.size.width, maxRect.height / image.size.height, 1)
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    image.draw(
                        in: CGRect(
                            x: maxRect.midX - size.width / 2, y: maxRect.midY - size.height / 2,
                            width: size.width, height: size.height))
                }
            }
        }
        try Task.checkCancellation()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "NarabiAIFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("AI_Sort_\(request.code)_\(lightweight ? "Light" : "High").pdf")
        try data.write(to: url, options: .atomic)
        return AIPackageResult(url: url, request: request)
    }

    static func makeText(
        projectID: UUID, indexedPages: [(index: Int, page: ProjectPage)], prompt: String, corrected: Bool,
        progress: @escaping @MainActor (Int, Int) -> Void
    ) async throws -> AIPackageResult {
        guard let request = request(projectID: projectID, pages: indexedPages, prompt: prompt) else {
            throw CancellationError()
        }
        let results = try await AIOCRService.recognize(
            pages: indexedPages.map(\.page), corrected: corrected, progress: progress)
        try Task.checkCancellation()
        let data = AIOCRService.package(session: request.code, prompt: prompt, results: results)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "NarabiAIFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(
            "AI_Sort_\(request.code)_\(corrected ? "Corrected" : "Basic").txt")
        try data.write(to: url, options: .atomic)
        return AIPackageResult(url: url, request: request)
    }

    static func removeTemporaryFile(_ url: URL?) {
        guard let url, url.path.contains("NarabiAIFiles") else { return }
        try? FileManager.default.removeItem(at: url)
    }
    private static func instructions(code: String, prompt: String, includeReason: Bool) -> String {
        """
        AI SORT REQUEST / AI並べ替え依頼
        [AI TASK INSTRUCTIONS - DO NOT TRANSLATE THESE RULES]
        SESSION_ID: \(code)
        PREFERRED_LANGUAGE: \(Locale.preferredLanguages.first ?? "en")
        Read every supplied page and arrange every P-style PAGE_ID exactly once according to USER_SORTING_RULES.
        Return exactly one machine-readable payload line in one fenced code block when possible:
        SESSION:\(code)|ORDER:P003,P001,P002|REASON:<short reason>
        Do not translate SESSION, ORDER, REASON, or PAGE_ID. \(includeReason ? "REASON must be a short user-facing reason." : "REASON may be empty.")
        USER_SORTING_RULES:
        \(prompt)
        """
    }
    private static func drawWrapped(_ text: String, rect: CGRect, font: UIFont) {
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: UIColor.label])
    }
    static func parse(_ text: String, request: ActiveAISortRequest) -> Result<([String], String), Error> {
        let normalized = text.replacingOccurrences(of: "\r", with: "\n")
        let candidateLines = normalized.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains("SESSION:") && $0.contains("|ORDER:") && $0.contains("|REASON:") }

        guard let rawLine = candidateLines.first else {
            return .failure(
                NSError(
                    domain: "AISort", code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: L10n.text(
                            "ai.error.resultLineNotFound", "貼り付け内容から結果行を見つけられませんでした。")
                    ]))
        }

        let line =
            rawLine
            .replacingOccurrences(of: "```text", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let sessionRange = line.range(of: "SESSION:"),
            let orderMarker = line.range(of: "|ORDER:"),
            let reasonMarker = line.range(of: "|REASON:")
        else {
            return .failure(
                NSError(
                    domain: "AISort", code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey: L10n.text("ai.error.invalidFormat", "結果形式が正しくありません。")
                    ]))
        }

        let session = String(line[sessionRange.upperBound..<orderMarker.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard session == request.code else {
            return .failure(
                NSError(
                    domain: "AISort", code: 3,
                    userInfo: [
                        NSLocalizedDescriptionKey: L10n.text("ai.error.sessionMismatch", "SESSIONが一致しません。")
                    ]))
        }

        let orderText = String(line[orderMarker.upperBound..<reasonMarker.lowerBound])
        let ids = orderText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let expected = Set(request.pages.map(\.id))
        guard ids.count == expected.count, Set(ids) == expected else {
            return .failure(
                NSError(
                    domain: "AISort", code: 4,
                    userInfo: [
                        NSLocalizedDescriptionKey: L10n.text(
                            "ai.error.pageSetMismatch", "PAGE_IDに不足・重複・追加があります。")
                    ]))
        }

        let reason = String(line[reasonMarker.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return .success((ids, reason))
    }

}
