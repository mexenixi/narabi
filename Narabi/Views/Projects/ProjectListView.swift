import SwiftUI
import UIKit

enum ProjectBrowserItem: Identifiable, Equatable {
    case folder(ProjectFolder)
    case project(NarabiProject)
    var id: UUID {
        switch self {
        case .folder(let v): return v.id
        case .project(let v): return v.id
        }
    }
    var token: String {
        switch self {
        case .folder(let v): return "folder:\(v.id.uuidString)"
        case .project(let v): return "project:\(v.id.uuidString)"
        }
    }
    var name: String {
        switch self {
        case .folder(let v): return v.name
        case .project(let v): return v.outputName
        }
    }
}

struct ProjectListView: View {
    @EnvironmentObject private var store: ProjectStore
    @Binding var folderID: UUID?
    let back: () -> Void
    let open: (UUID) -> Void
    @State private var search = ""
    @State private var selection: [UUID] = []
    @State private var renameTarget: ProjectBrowserItem?
    @State private var nameDraft = ""
    @State private var showNewFolder = false
    @State private var moveTargets: [ProjectBrowserItem] = []
    @State private var deleteTargets: [ProjectBrowserItem] = []
    @FocusState private var nameFocused: Bool

    private var isSelecting: Bool { !selection.isEmpty }
    private var currentFolder: ProjectFolder? { folderID.flatMap(store.folder) }
    private var normalItems: [ProjectBrowserItem] {
        if let folderID { return store.projects(in: folderID).map(ProjectBrowserItem.project) }
        return store.rootItems.map { $0.folder.map(ProjectBrowserItem.folder) ?? .project($0.project!) }
    }
    private var visibleItems: [ProjectBrowserItem] {
        guard !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return normalItems }
        return store.searchItems(search).map {
            $0.folder.map(ProjectBrowserItem.folder) ?? .project($0.project!)
        }
    }
    private var selectedItems: [ProjectBrowserItem] {
        ProjectBrowserSelectionPolicy.selectedItems(from: normalItems, selection: selection)
    }

    var body: some View {
        NavigationStack {
            ProjectBrowserBoard(
                items: visibleItems,
                selection: selection,
                selectionMode: isSelecting,
                searchMode: !search.isEmpty,
                folderID: folderID,
                tap: tap,
                menu: showMenu,
                reorder: { tokens, target, after in
                    store.relocateDragged(items: tokens, to: folderID, target: target, placeAfter: after)
                    selection.removeAll()
                },
                enterFolder: { targetFolder, _ in folderID = targetFolder },
                returnToRoot: { _ in folderID = nil }
            )
            .searchable(text: $search, prompt: L10n.text("projects.search", "プロジェクトを検索"))
            .navigationTitle(currentFolder?.name ?? L10n.text("home.continue", "続きから"))
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if isSelecting { selection.removeAll() }
                        if folderID != nil { folderID = nil } else { back() }
                    } label: {
                        Label(
                            folderID == nil
                                ? L10n.text("common.back", "戻る") : L10n.text("home.continue", "続きから"),
                            systemImage: "chevron.left")
                    }.accessibilityIdentifier("ProjectBrowserBackTarget")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelecting {
                        Button(L10n.text("common.done", "完了")) { selection.removeAll() }
                    } else if folderID == nil {
                        Button {
                            nameDraft = ""
                            showNewFolder = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .alert(L10n.text("projects.newFolder", "新規フォルダ"), isPresented: $showNewFolder) {
                TextField(L10n.text("projects.folderName", "フォルダ名"), text: $nameDraft).focused($nameFocused)
                Button(L10n.text("common.cancel", "キャンセル"), role: .cancel) {}
                Button(L10n.text("common.create", "作成")) { store.createFolder(name: nameDraft) }.disabled(
                    nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.onChange(of: showNewFolder) { _, v in if v { Task { @MainActor in nameFocused = true } } }
            .alert(
                L10n.text("projects.rename", "名前を変更"),
                isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })
            ) {
                TextField(L10n.text("projects.name", "名前"), text: $nameDraft).focused($nameFocused)
                Button(L10n.text("common.cancel", "キャンセル"), role: .cancel) {}
                Button(L10n.text("common.done", "完了")) {
                    guard let t = renameTarget else { return }
                    switch t {
                    case .folder(let f): store.renameFolder(id: f.id, name: nameDraft)
                    case .project(let p): store.renameProject(id: p.id, name: nameDraft)
                    }
                    renameTarget = nil
                }
            }.onChange(of: renameTarget) { _, v in if v != nil { Task { @MainActor in nameFocused = true } } }
            .confirmationDialog(
                L10n.text("projects.move", "移動"),
                isPresented: Binding(get: { !moveTargets.isEmpty }, set: { if !$0 { moveTargets = [] } }),
                titleVisibility: .visible
            ) {
                Button {
                    move(moveTargets, to: nil)
                } label: {
                    Label(L10n.text("home.continue", "続きから"), systemImage: "house")
                }
                ForEach(store.folders) { f in Button(f.name) { move(moveTargets, to: f.id) } }
                Button(L10n.text("common.cancel", "キャンセル"), role: .cancel) { moveTargets = [] }
            }
            .confirmationDialog(
                deleteTargets.count > 1
                    ? L10n.text("projects.deleteSelected", "選択した項目を削除しますか？")
                    : L10n.text("projects.deleteOne", "この項目を削除しますか？"),
                isPresented: Binding(get: { !deleteTargets.isEmpty }, set: { if !$0 { deleteTargets = [] } }),
                titleVisibility: .visible
            ) {
                Button(L10n.text("common.delete", "削除"), role: .destructive) {
                    store.delete(items: deleteTargets.map(\.token))
                    selection.removeAll()
                    deleteTargets = []
                }
                Button(L10n.text("common.cancel", "キャンセル"), role: .cancel) { deleteTargets = [] }
            } message: {
                Text(
                    ProjectBrowserSelectionPolicy.containsFolder(deleteTargets)
                        ? L10n.text("projects.deleteFolderWarning", "フォルダ内のプロジェクトもすべて完全に削除されます。この操作は取り消せません。")
                        : L10n.text("projects.deleteWarning", "この操作は取り消せません。"))
            }
        }
    }
    private func tap(_ item: ProjectBrowserItem) {
        if isSelecting {
            ProjectBrowserSelectionPolicy.toggle(item.id, selection: &selection)
            return
        }
        switch item {
        case .folder(let f): folderID = f.id
        case .project(let p): open(p.id)
        }
    }
    private func showMenu(_ item: ProjectBrowserItem) {
        let targets = ProjectBrowserSelectionPolicy.actionTargets(
            pressed: item,
            selectionMode: isSelecting,
            items: normalItems,
            selection: selection
        )
        let a = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if !isSelecting {
            a.addAction(
                UIAlertAction(title: L10n.text("common.select", "選択"), style: .default) { _ in
                    selection = [item.id]
                })
            a.addAction(
                UIAlertAction(title: L10n.text("projects.rename", "名前を変更"), style: .default) { _ in
                    renameTarget = item
                    nameDraft = item.name
                })
        }
        a.addAction(
            UIAlertAction(title: L10n.text("projects.duplicate", "複製"), style: .default) { _ in
                store.duplicate(items: targets.map(\.token))
                selection.removeAll()
            })
        if ProjectBrowserSelectionPolicy.canMove(targets) {
            a.addAction(
                UIAlertAction(title: L10n.text("projects.move", "移動"), style: .default) { _ in
                    moveTargets = targets
                })
        }
        a.addAction(
            UIAlertAction(title: L10n.text("common.delete", "削除"), style: .destructive) { _ in
                deleteTargets = targets
            })
        a.addAction(UIAlertAction(title: L10n.text("common.cancel", "キャンセル"), style: .cancel))
        UIApplication.shared.firstKeyWindow?.rootViewController?.topController.present(a, animated: true)
    }
    private func move(_ targets: [ProjectBrowserItem], to id: UUID?) {
        store.move(items: targets.map(\.token), to: id)
        selection.removeAll()
        moveTargets = []
    }
}
private extension UIApplication {
    var firstKeyWindow: UIWindow? {
        connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }
    }
}
private extension UIViewController {
    var topController: UIViewController {
        if let p = presentedViewController { return p.topController }
        if let n = self as? UINavigationController { return n.visibleViewController?.topController ?? n }
        return self
    }
}
