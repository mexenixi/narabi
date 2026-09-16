import SwiftUI
import UIKit

struct WorkspaceBoard: UIViewControllerRepresentable {
    @Binding var project: NarabiProject
    @Binding var editorSelection: [UUID]
    @Binding var traySelection: [UUID]

    let editorSelectionMode: Bool
    let traySelectionMode: Bool
    let toggleTraySelectionMode: () -> Void
    let toggleTrayCollapsed: () -> Void
    let deleteTraySelection: () -> Void
    let checkpoint: () -> Void
    let save: () -> Void
    let openPageMenu: (ProjectPage, WorkspaceArea) -> Void
    let openPreview: (ProjectPage, String) -> Void
    let requestTrayPlacement: (UUID, UUID) -> Void

    func makeUIViewController(context: Context) -> WorkspaceBoardController {
        let controller = WorkspaceBoardController()
        controller.events = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ controller: WorkspaceBoardController,
        context: Context
    ) {
        context.coordinator.parent = self
        controller.toggleTraySelectionMode = toggleTraySelectionMode
        controller.toggleTrayCollapsed = toggleTrayCollapsed
        controller.deleteTraySelection = deleteTraySelection
        controller.selectAllTrayItems = {
            let chosen = Set(context.coordinator.parent.traySelection)
            context.coordinator.parent.traySelection.append(
                contentsOf: context.coordinator.parent.project.tray.map(\.id).filter { !chosen.contains($0) })
        }
        controller.clearTraySelectionItems = { context.coordinator.parent.traySelection.removeAll() }
        controller.apply(
            project: project,
            editorSelection: editorSelection,
            traySelection: traySelection,
            editorSelectionMode: editorSelectionMode,
            traySelectionMode: traySelectionMode
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: WorkspaceBoardEvents {
        var parent: WorkspaceBoard

        init(parent: WorkspaceBoard) {
            self.parent = parent
        }

        func tap(item: ProjectPage, area: WorkspaceArea) {
            switch area {
            case .editor:
                if parent.editorSelectionMode {
                    toggle(item.id, in: &parent.editorSelection)
                } else {
                    parent.openPageMenu(item, area)
                }
            case .tray:
                if parent.traySelectionMode {
                    toggle(item.id, in: &parent.traySelection)
                } else {
                    parent.openPageMenu(item, area)
                }
            }
        }

        func preview(item: ProjectPage, title: String) {
            parent.openPreview(item, title)
        }

        func moveWithin(
            area: WorkspaceArea,
            ids: [UUID],
            destination: Int
        ) {
            parent.checkpoint()
            switch area {
            case .editor:
                move(ids: ids, in: &parent.project.pages, destination: destination)
                parent.editorSelection.removeAll()
            case .tray:
                move(ids: ids, in: &parent.project.tray, destination: destination)
                parent.traySelection.removeAll()
            }
            parent.save()
        }

        func moveEditorToTray(ids: [UUID], destination: Int) {
            parent.checkpoint()
            let movingIDs = Set(ids)
            let moving = parent.project.pages.filter { movingIDs.contains($0.id) }
            parent.project.pages.removeAll { movingIDs.contains($0.id) }
            let index = min(max(destination, 0), parent.project.tray.count)
            parent.project.tray.insert(contentsOf: moving, at: index)
            parent.editorSelection.removeAll()
            parent.save()
        }

        func moveTrayToEditor(
            ids: [UUID],
            destination: Int,
            destinationItemID: UUID?
        ) {
            guard !ids.isEmpty else { return }

            // 1枚だけを既存ページ上へ落とした場合に限り、
            // 追加・入れ替え・更新の選択を表示します。
            if ids.count == 1,
                let id = ids.first,
                let destinationItemID
            {
                parent.requestTrayPlacement(id, destinationItemID)
                return
            }

            // 複数選択時は「追加」だけです。
            // 選択番号順を保ち、指定位置または最後尾へまとめて挿入します。
            let movingIDs = Set(ids)
            let moving = parent.project.tray.filter { movingIDs.contains($0.id) }
            guard !moving.isEmpty else { return }

            parent.checkpoint()
            parent.project.tray.removeAll { movingIDs.contains($0.id) }
            let index = min(max(destination, 0), parent.project.pages.count)
            parent.project.pages.insert(contentsOf: moving, at: index)
            parent.traySelection.removeAll()
            parent.save()
        }

        private func toggle(_ id: UUID, in selection: inout [UUID]) {
            if let index = selection.firstIndex(of: id) {
                selection.remove(at: index)
            } else {
                selection.append(id)
            }
        }

        private func move(
            ids: [UUID],
            in array: inout [ProjectPage],
            destination: Int
        ) {
            guard !ids.isEmpty else { return }

            // destination is the final zero-based position of the first moved page.
            // Do not subtract removed source positions. For example, display 1 -> 10
            // means remove index 0 and insert directly at index 9.
            let moving = ids.compactMap { id in
                array.first { $0.id == id }
            }
            guard !moving.isEmpty else { return }
            array.removeAll { ids.contains($0.id) }
            let finalIndex = min(max(destination, 0), array.count)
            array.insert(contentsOf: moving, at: finalIndex)
        }
    }
}

enum WorkspaceArea {
    case editor
    case tray
}

@MainActor
protocol WorkspaceBoardEvents: AnyObject {
    func tap(item: ProjectPage, area: WorkspaceArea)
    func preview(item: ProjectPage, title: String)
    func moveWithin(area: WorkspaceArea, ids: [UUID], destination: Int)
    func moveEditorToTray(ids: [UUID], destination: Int)
    func moveTrayToEditor(ids: [UUID], destination: Int, destinationItemID: UUID?)
}
