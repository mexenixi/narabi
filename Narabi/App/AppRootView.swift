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
    @State private var didRestoreScene = false
    @SceneStorage("narabi.root.screen") private var storedScreen = "home"
    @SceneStorage("narabi.root.projectID") private var storedProjectID = ""
    @SceneStorage("narabi.root.folderID") private var storedFolderID = ""
    @AppStorage(L10n.languageKey) private var appLanguage = "system"

    var body: some View {
        Group {
            switch screen {
            case .home:
                HomeView(newProject: showNewImport, continueProject: showRootProjectList)
            case .importNew:
                ImportView(cancel: showHome, confirmed: showEditor)
            case .list:
                ProjectListView(folderID: $projectBrowserFolderID, back: showHome, open: showEditor)
            case .editor(let id):
                EditorView(projectID: id, close: closeEditorToProjectList)
            }
        }
        .environment(\.locale, L10n.locale)
        .environment(\.layoutDirection, L10n.layoutDirection)
        .id(L10n.refreshID)
        .onAppear { restoreSceneIfNeeded() }
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
        projectBrowserFolderID = nil
        screen = .home
        persistCurrentScreen()
    }

    private func showNewImport() {
        projectBrowserFolderID = nil
        screen = .importNew
        persistCurrentScreen()
    }

    private func showRootProjectList() {
        projectBrowserFolderID = nil
        screen = .list
        persistCurrentScreen()
    }

    private func closeEditorToProjectList() {
        screen = .list
        persistCurrentScreen()
    }

    private func showEditor(_ id: UUID) {
        screen = .editor(id)
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
