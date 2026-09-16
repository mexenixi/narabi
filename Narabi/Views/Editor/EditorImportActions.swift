import PDFKit
import Photos
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

extension EditorView {
    func addPhotosToTray(_ selections: [PhotosPickerItem]) async {
        var added: [ProjectPage] = []
        for selection in selections {
            guard let data = try? await selection.loadTransferable(type: Data.self),
                let image = UIImage(data: data),
                let page = EditorImportPipeline.page(from: image)
            else { continue }
            added.append(page)
        }
        await MainActor.run {
            if !added.isEmpty {
                checkpoint()
                project.tray.append(contentsOf: added)
                save()
            }
            presentImportSummary(inputCount: selections.count, successCount: added.count)
            photoSelections = []
        }
    }

    @MainActor
    func addFilesToTray(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result else { return }
        importProgress.begin(totalFiles: urls.count)
        defer { importProgress.finish() }

        var added: [ProjectPage] = []
        var successfulItems = 0

        for (fileIndex, url) in urls.enumerated() {
            if importProgress.cancellationRequested { return }
            importProgress.currentFile = fileIndex + 1
            importProgress.phase = L10n.text("import.progress.reading", "文書の内容を読み取っています")

            let pages = await importPages(from: url)
            if !pages.isEmpty {
                added.append(contentsOf: pages)
                successfulItems += 1
                importProgress.generatedPages = added.count
            }
        }

        if !added.isEmpty {
            checkpoint()
            project.tray.append(contentsOf: added)
            save()
        }
        presentImportSummary(inputCount: urls.count, successCount: successfulItems)
    }

    @MainActor
    private func importPages(from url: URL) async -> [ProjectPage] {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else { return [] }
        let format = ImportFormatPolicy.classify(url: url, data: data)

        if format.isPDF {
            importProgress.phase = L10n.text("import.progress.pages", "ページを作成しています")
            importProgress.currentUnit = 0
            importProgress.totalUnits = PDFDocument(data: data)?.pageCount ?? 0
            let pages = await EditorImportPipeline.pages(fromPDFData: data) { current, total in
                importProgress.currentUnit = current
                importProgress.totalUnits = total
                return !importProgress.cancellationRequested
            }
            importProgress.currentUnit = 0
            importProgress.totalUnits = 0
            return pages
        }

        if format.isImage {
            return EditorImportPipeline.page(fromImageData: data).map { [$0] } ?? []
        }

        if format.canPageize {
            let images: [UIImage]
            do {
                images = try await Task.detached(priority: .userInitiated) {
                    try DocumentPageImportService.pageImages(for: url)
                }.value
            } catch is DocumentImportSafetyError {
                // Count this item as failed and continue with the remaining selections.
                images = []
            } catch {
                images = []
            }
            let pages = images.compactMap(EditorImportPipeline.page(from:))
            if !pages.isEmpty { return pages }
        }

        if format.isOfficePreviewCandidate,
            let preview = await OfficeImportService.previewPage(for: url),
            let page = EditorImportPipeline.page(from: preview)
        {
            return [page]
        }
        return []
    }

    @MainActor
    private func presentImportSummary(inputCount: Int, successCount: Int) {
        let failedCount = max(inputCount - successCount, 0)
        guard failedCount > 0 else { return }
        if successCount == 0 {
            importResultMessage = L10n.text(
                "import.result.failed", "選択した項目を読み込めませんでした。ファイル形式、内容、ファイルサイズを確認してください。")
        } else {
            importResultMessage = String(
                format: L10n.text("import.result.partial", "%1$lld件中%2$lld件を追加しました。%3$lld件は読み込めませんでした。"),
                Int64(inputCount),
                Int64(successCount),
                Int64(failedCount)
            )
        }
        showImportResult = true
    }

    func addScansToTray(_ images: [UIImage]) {
        let added = images.compactMap(EditorImportPipeline.page(from:))
        guard !added.isEmpty else { return }
        checkpoint()
        project.tray.append(contentsOf: added)
        save()
        showScanner = false
    }
}
