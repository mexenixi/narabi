import SwiftUI

struct AppRootView: View {
    enum Screen: Equatable {
        case home, importNew, list
        case editor(UUID)
    }

    @EnvironmentObject private var store: ProjectStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var screen: Screen = .home
    @State private var projectBrowserFolderID: UUID?
    @State private var externalFileURLs: [URL] = []
    @State private var importSessionID = UUID()
    @State private var didRestoreScene = false
    @SceneStorage("narabi.root.screen") private var storedScreen = "home"
    @SceneStorage("narabi.root.projectID") private var storedProjectID = ""
    @SceneStorage("narabi.root.folderID") private var storedFolderID = ""
    @SceneStorage("narabi.root.importReturnToList") private var importReturnToList = false
    @AppStorage(L10n.languageKey) private var appLanguage = "system"

    var body: some View {
        Group {
            switch screen {
            case .home:
                HomeView(newProject: showNewImport, continueProject: showRootProjectList)
            case .importNew:
                ImportView(
                    cancel: cancelImport,
                    confirmed: showEditor,
                    initialFileURLs: externalFileURLs
                )
                .id(importSessionID)
            case .list:
                ProjectListView(
                    folderID: $projectBrowserFolderID,
                    back: showHome,
                    open: showEditor,
                    newProject: showNewImportFromProjectList
                )
            case .editor(let id):
                EditorView(projectID: id, close: closeEditorToProjectList)
            }
        }
        .environment(\.locale, L10n.locale)
        .environment(\.layoutDirection, L10n.layoutDirection)
        .id(L10n.refreshID)
        .onAppear { restoreSceneIfNeeded() }
        .onOpenURL(perform: openSharedDocument)
        .alert(
            L10n.text("error.saveTitle", "保存できませんでした"),
            isPresented: Binding(
                get: { store.persistenceErrorMessage != nil },
                set: { if !$0 { store.persistenceErrorMessage = nil } }
            )
        ) {
            Button(L10n.text("common.ok", "OK")) {}
        } message: {
            Text(store.persistenceErrorMessage ?? "")
        }
        .onChange(of: appLanguage) { _, _ in }
        .onChange(of: projectBrowserFolderID) { _, id in
            storedFolderID = id?.uuidString ?? ""
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { persistCurrentScreen() }
        }
    }

    private func showHome() {
        externalFileURLs.removeAll()
        projectBrowserFolderID = nil
        screen = .home
        persistCurrentScreen()
    }

    private func cancelImport() {
        if importReturnToList {
            showRootProjectList()
        } else {
            showHome()
        }
    }

    private func showNewImport() {
        importReturnToList = false
        openNewImport()
    }

    private func showNewImportFromProjectList() {
        importReturnToList = true
        openNewImport()
    }

    private func openNewImport() {
        externalFileURLs.removeAll()
        importSessionID = UUID()
        projectBrowserFolderID = nil
        screen = .importNew
        persistCurrentScreen()
    }

    private func showRootProjectList() {
        externalFileURLs.removeAll()
        projectBrowserFolderID = nil
        screen = .list
        persistCurrentScreen()
    }

    private func closeEditorToProjectList() {
        screen = .list
        persistCurrentScreen()
    }

    private func showEditor(_ id: UUID) {
        externalFileURLs.removeAll()
        screen = .editor(id)
        persistCurrentScreen()
    }

    private func openSharedDocument(_ url: URL) {
        guard url.isFileURL else { return }
        didRestoreScene = true
        importReturnToList = false
        if !externalFileURLs.contains(url) { externalFileURLs.append(url) }
        projectBrowserFolderID = nil
        screen = .importNew
        persistCurrentScreen()
    }

    private func persistCurrentScreen() {
        storedFolderID = projectBrowserFolderID?.uuidString ?? ""
        switch screen {
        case .home:
            storedScreen = "home"
            storedProjectID = ""
        case .importNew:
            storedScreen = "importNew"
            storedProjectID = ""
        case .list:
            storedScreen = "list"
            storedProjectID = ""
        case .editor(let id):
            storedScreen = "editor"
            storedProjectID = id.uuidString
        }
    }

    private func restoreSceneIfNeeded() {
        guard !didRestoreScene else { return }
        didRestoreScene = true
        projectBrowserFolderID = UUID(uuidString: storedFolderID)
        switch storedScreen {
        case "editor":
            if let id = UUID(uuidString: storedProjectID), store.project(id: id) != nil {
                screen = .editor(id)
            } else {
                storedProjectID = ""
                storedScreen = "list"
                screen = .list
            }
        case "list":
            screen = .list
        case "importNew":
            screen = .importNew
        default:
            screen = .home
        }
    }
}
