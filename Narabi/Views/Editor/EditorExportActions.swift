import PDFKit
import Photos
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

extension EditorView {
    var pagesForCompositeEditing: [ProjectPage] {
        editorSelection.isEmpty
            ? project.pages
            : editorSelection.compactMap { id in
                project.pages.first { $0.id == id }
            }
    }

    var pagesForOutput: [ProjectPage] {
        let ordered =
            editorSelection.isEmpty
            ? project.pages : editorSelection.compactMap { id in project.pages.first { $0.id == id } }
        return ordered.filter { !$0.isHiddenFromPreviewAndOutput }
    }

    func mutatePage(id: UUID, change: (inout ProjectPage) -> Void) {
        if let index = project.pages.firstIndex(where: { $0.id == id }) {
            change(&project.pages[index])
        } else if let index = project.tray.firstIndex(where: { $0.id == id }) {
            change(&project.tray[index])
        } else {
            return
        }
        save()
    }

    func exportComposite() {
        let settings = ProductSettings.shared

        guard
            let image = ExportService.compositeImage(
                pages: pagesForOutput, transparent: exportPreset == .transparentPNG,
                longEdge: settings.effectiveLongEdge(for: exportPreset),
                colorPolicy: settings.exportColorPolicy,
                customPixelSize: settings.exactCustomPixelSize)
        else { return }

        let name = ExportService.safeFileBaseName(project.outputName)
        compositePreview = nil
        Task {
            do {
                switch exportPreset {
                case .pdf:
                    let data = ExportService.compositePDFData(image)
                    guard !data.isEmpty else { throw CocoaError(.fileWriteUnknown) }
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                        .appendingPathExtension("pdf")
                    try data.write(to: url, options: .atomic)
                    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0 else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    await MainActor.run {
                        countPendingSharedExport = true
                        shareItems = [url]
                    }
                case .jpeg:
                    guard let data = image.jpegData(compressionQuality: settings.jpegQuality), !data.isEmpty
                    else { throw CocoaError(.fileWriteUnknown) }
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                        .appendingPathExtension("jpg")
                    try data.write(to: url, options: .atomic)
                    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0 else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    await MainActor.run {
                        countPendingSharedExport = true
                        shareItems = [url]
                    }
                case .png, .transparentPNG:
                    guard let data = image.pngData(), !data.isEmpty else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                        .appendingPathExtension("png")
                    try data.write(to: url, options: .atomic)
                    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0 else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    await MainActor.run {
                        countPendingSharedExport = true
                        shareItems = [url]
                    }
                case .photos:
                    try await ExportService.saveCompositeToPhotos(image)
                    await MainActor.run {
                        showPhotoSavedToast = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.6))
                            showPhotoSavedToast = false
                        }
                        recordSuccessfulExport()
                    }
                }
            } catch is CancellationError {
            } catch {
                await MainActor.run {
                    exportErrorMessage = error.localizedDescription
                    showExportError = true
                }
            }
        }
    }

    func recordSuccessfulExport() {
        if ReviewRequestTracker.recordSuccessfulExport() {
            requestReview()
        }
    }
    func performExport() {
        commitOutputName()
        let pages = pagesForOutput

        guard !pages.isEmpty else {

            return
        }
        if mergePages {

            compositeEntrySelection = editorSelection
            showCompositeEditor = true
            return
        }
        if exportPreset != .photos {
            let safeName = ExportService.safeFileBaseName(project.outputName)
            guard !safeName.isEmpty else {
                showNameRequest = true
                return
            }
            if safeName != project.outputName {
                project.outputName = safeName
                save()
            }
        }

        let settings = ProductSettings.shared
        exportTask?.cancel()
        let progressTotal = pages.filter { !$0.isHiddenFromPreviewAndOutput }.count
        exportProgress = ExportProgress(completed: 0, total: progressTotal, message: "0 / \(progressTotal)")
        exportTask = Task {
            switch exportPreset {
            case .pdf:

                do {
                    if let data = try await PDFBuilder.makeOptimized(
                        pages: pages, colorPolicy: settings.exportColorPolicy,
                        progress: { completed, total in
                            exportProgress = ExportProgress(
                                completed: completed, total: total, message: "\(completed) / \(total)")
                        })
                    {
                        let name = ExportService.safeFileBaseName(project.outputName)
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                            .appendingPathExtension("pdf")
                        do {
                            try data.write(to: url, options: .atomic)

                            await MainActor.run {

                                countPendingSharedExport = true
                                shareItems = [url]
                                exportProgress = nil
                            }
                        } catch {

                            await MainActor.run { exportProgress = nil }
                        }
                    }
                } catch is CancellationError {
                    await MainActor.run { exportProgress = nil }
                } catch {

                    await MainActor.run { exportProgress = nil }
                }
            case .jpeg, .png, .transparentPNG:
                do {
                    let result = try await ExportService.imageFiles(
                        pages: pages,
                        preset: exportPreset,
                        longEdge: settings.exportLongEdge,
                        jpegQuality: settings.jpegQuality,
                        colorPolicy: settings.exportColorPolicy,
                        customPixelSize: settings.exactCustomPixelSize,
                        baseName: ExportService.safeFileBaseName(project.outputName)
                    ) { value in
                        Task { @MainActor in exportProgress = value }
                    }
                    try Task.checkCancellation()
                    await MainActor.run {
                        normalImageExportDirectory = result.directory
                        countPendingSharedExport = true
                        shareItems = result.urls
                        exportProgress = nil
                    }
                } catch is CancellationError {
                    await MainActor.run { exportProgress = nil }
                } catch {
                    await MainActor.run {
                        exportProgress = nil
                        exportErrorMessage = error.localizedDescription
                        showExportError = true
                    }
                }
            case .photos:

                do {
                    try await ExportService.saveToPhotos(
                        pages: pages, longEdge: settings.exportLongEdge,
                        colorPolicy: settings.exportColorPolicy
                    ) { value in
                        Task { @MainActor in exportProgress = value }
                    }
                    await MainActor.run {

                        showPhotoSavedToast = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.6))
                            showPhotoSavedToast = false
                        }
                        exportProgress = nil
                        recordSuccessfulExport()
                    }
                } catch {

                    await MainActor.run { exportProgress = nil }
                }
            }
        }
    }
}
