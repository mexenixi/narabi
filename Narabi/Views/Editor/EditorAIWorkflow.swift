import PDFKit
import Photos
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

extension EditorView {
    func startAIRequest() {
        aiPromptDraft = ProductSettings.shared.aiSortingPrompt
        activeAIRequest = nil
        activeAIFileURL = nil
        aiResultText = ""
        aiMode = true
    }
    func createAndShareAIFile() {
        let indexed: [(index: Int, page: ProjectPage)] =
            editorSelection.isEmpty
            ? project.pages.enumerated().map { ($0.offset, $0.element) }
            : project.pages.enumerated().filter { Set(editorSelection).contains($0.element.id) }.map {
                ($0.offset, $0.element)
            }
        let settings = AIReadSettings.shared
        aiCreationProgress = ExportProgress(
            completed: 0, total: indexed.count, message: "0 / \(indexed.count)")
        aiCreationTask = Task {
            do {
                let progress: @MainActor (Int, Int) -> Void = { done, total in
                    aiCreationProgress = ExportProgress(
                        completed: done, total: total, message: "\(done) / \(total)")
                }
                let package: AIPackageResult
                switch settings.mode {
                case .pdf:
                    package = try await AISortPackageService.makePDF(
                        projectID: project.id, pages: indexed, prompt: aiPromptDraft,
                        includeReason: ProductSettings.shared.aiIncludeReason,
                        lightweight: settings.pdfQuality == .light, progress: progress)
                case .text:
                    package = try await AISortPackageService.makeText(
                        projectID: project.id, indexedPages: indexed, prompt: aiPromptDraft,
                        corrected: settings.ocrPreparation == .corrected, progress: progress)
                }
                try Task.checkCancellation()
                activeAIRequest = package.request
                activeAIFileURL = package.url
                aiResultText = ""
                shareItems = [package.url]
            } catch is CancellationError {} catch {
                aiErrorMessage = error.localizedDescription
                showAIError = true
            }
            aiCreationProgress = nil
            aiCreationTask = nil
        }
    }
    func cancelAIRequest() {
        aiCreationTask?.cancel()
        aiCreationTask = nil
        aiCreationProgress = nil
        AISortPackageService.removeTemporaryFile(activeAIFileURL)
        activeAIRequest = nil
        activeAIFileURL = nil
        aiResultText = ""
        shareItems = []
        aiMode = false
    }

    func applyAIResult() {
        guard let request = activeAIRequest else { return }
        switch AISortPackageService.parse(aiResultText, request: request) {
        case .failure(let error):
            aiErrorMessage = error.localizedDescription
            showAIError = true
        case .success(let value):
            pendingAIOrder = value.0
            pendingAIReason = value.1
            showAIConfirmation = true
        }
    }

    func commitPendingAIResult() {
        guard let request = activeAIRequest else { return }
        let refs = Dictionary(uniqueKeysWithValues: request.pages.map { ($0.id, $0) })
        let orderedIDs = pendingAIOrder.compactMap { refs[$0]?.pageID }
        let targetIndexes = request.pages.map(\.fixedEditorIndex).sorted()
        let pageMap = Dictionary(uniqueKeysWithValues: project.pages.map { ($0.id, $0) })
        let orderedPages = orderedIDs.compactMap { pageMap[$0] }
        guard orderedPages.count == targetIndexes.count else {
            aiErrorMessage = L10n.text("ai.error.pageMismatch", "対象ページが一致しません")
            showAIError = true
            return
        }
        checkpoint()
        for (index, page) in zip(targetIndexes, orderedPages) where project.pages.indices.contains(index) {
            project.pages[index] = page
        }
        save()
        pendingAIOrder = []
        pendingAIReason = ""
        cancelAIRequest()
    }
}
