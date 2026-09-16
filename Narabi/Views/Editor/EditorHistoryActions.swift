import PDFKit
import Photos
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

extension EditorView {
    func checkpoint() {
        appendHistory(project, to: &undoStack)
        redoStack.removeAll()
    }

    func undo() {
        guard var previous = undoStack.popLast() else { return }
        let currentTrayCollapsed = project.isTrayCollapsed
        appendHistory(project, to: &redoStack)
        previous.isTrayCollapsed = currentTrayCollapsed
        project = previous
        save()
    }

    func redo() {
        guard var next = redoStack.popLast() else { return }
        let currentTrayCollapsed = project.isTrayCollapsed
        appendHistory(project, to: &undoStack)
        next.isTrayCollapsed = currentTrayCollapsed
        project = next
        save()
    }

    func appendHistory(_ snapshot: NarabiProject, to stack: inout [NarabiProject]) {
        stack.append(snapshot)
        EditorHistoryPolicy.trim(&stack)
    }

    func closeEditorImmediately() {
        guard !isClosingEditor else { return }
        isClosingEditor = true
        outputNameFocused = false
        commitOutputName()
        let finalProject = project

        close()
        Task { @MainActor in
            await Task.yield()
            store.update(finalProject)
        }
    }

    func commitOutputName() {
        guard project.outputName != outputNameDraft else { return }
        project.outputName = outputNameDraft
    }

    func save() {
        store.update(project)
    }
}
