import PDFKit
import Photos
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

extension EditorView {
    func applySingleTrayDrop(_ drop: PendingTrayDrop, action: TrayDropAction) {
        guard let sourceIndex = project.tray.firstIndex(where: { $0.id == drop.sourceID }),
            let destinationIndex = project.pages.firstIndex(where: { $0.id == drop.destinationID })
        else {
            pendingTrayDrop = nil
            return
        }

        checkpoint()
        let incoming = project.tray.remove(at: sourceIndex)

        switch action {
        case .add:
            project.pages.insert(incoming, at: destinationIndex)
        case .swap:
            let old = project.pages[destinationIndex]
            project.pages[destinationIndex] = incoming
            project.tray.append(old)
        case .update:
            let old = project.pages[destinationIndex]
            project.pages[destinationIndex] = incoming
            project.deleted.append(old)
        }

        pendingTrayDrop = nil
        editorSelection.removeAll()
        traySelection.removeAll()
        save()
    }

    func deleteEditorSelection() {
        checkpoint()
        let chosen = editorSelection.compactMap { id in project.pages.first { $0.id == id } }
        project.pages.removeAll { editorSelection.contains($0.id) }
        project.deleted.append(contentsOf: chosen)
        editorSelection.removeAll()
        save()
    }

    func deleteTraySelection() {
        checkpoint()
        let chosen = traySelection.compactMap { id in project.tray.first { $0.id == id } }
        project.tray.removeAll { traySelection.contains($0.id) }
        project.deleted.append(contentsOf: chosen)
        traySelection.removeAll()
        save()
    }

    func remove(_ id: UUID, from area: DragArea, sendTo target: RemoveTarget) {
        let item: ProjectPage?
        if area == .editor {
            item = project.pages.first { $0.id == id }
            project.pages.removeAll { $0.id == id }
        } else {
            item = project.tray.first { $0.id == id }
            project.tray.removeAll { $0.id == id }
        }
        guard let item else { return }
        if target == .tray { project.tray.append(item) }
        if target == .deleted { project.deleted.append(item) }
    }

    func applyPageEdit(target: EditingTarget, changed: ProjectPage) {
        checkpoint()
        if target.area == .editor,
            let index = project.pages.firstIndex(where: { $0.id == target.item.id })
        {
            project.pages[index] = changed
        }
        if target.area == .tray,
            let index = project.tray.firstIndex(where: { $0.id == target.item.id })
        {
            project.tray[index] = changed
        }
        save()
    }

    func applyCompositePages(_ updated: [ProjectPage]) {
        let targetIDs = Set(updated.map(\.id))
        let targetIndexes = project.pages.indices.filter { targetIDs.contains(project.pages[$0].id) }
        guard targetIndexes.count == updated.count else { return }
        for (index, page) in zip(targetIndexes, updated) {
            project.pages[index] = page
        }
    }

    func duplicatePage(_ item: ProjectPage, area: DragArea) {
        checkpoint()
        var duplicate = item
        duplicate.id = UUID()
        switch area {
        case .editor:
            guard let index = project.pages.firstIndex(where: { $0.id == item.id }) else { return }
            project.pages.insert(duplicate, at: index + 1)
        case .tray:
            guard let index = project.tray.firstIndex(where: { $0.id == item.id }) else { return }
            project.tray.insert(duplicate, at: index + 1)
        }
        save()
    }
}
