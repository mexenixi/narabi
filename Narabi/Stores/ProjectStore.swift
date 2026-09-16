import Combine
import Foundation

struct ProjectBrowserRecord {
    let folder: ProjectFolder?
    let project: NarabiProject?
}

@MainActor final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [NarabiProject] = []
    @Published private(set) var folders: [ProjectFolder] = []
    @Published var persistenceErrorMessage: String?
    private let saveURL: URL
    private let foldersURL: URL
    private let saveBackupURL: URL
    private let foldersBackupURL: URL
    private var saveDebounceTask: Task<Void, Never>?
    private var persistenceWorkerTask: Task<Void, Never>?
    private var persistenceGeneration = 0
    private var persistenceRequested = false
    private let storageRootURL: URL
    private var persistedProjectRevisions: [UUID: ProjectPersistence.Revision] = [:]

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let fm = FileManager.default
        let folder = base.appendingPathComponent("NarabiAppData", isDirectory: true)
        let newFile = folder.appendingPathComponent("projects.json")
        storageRootURL = folder
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        saveURL = newFile
        foldersURL = folder.appendingPathComponent("projectFolders.json")
        saveBackupURL = folder.appendingPathComponent("projects.backup.json")
        foldersBackupURL = folder.appendingPathComponent("projectFolders.backup.json")
        TemporaryFileMaintenance.removeOldOwnedTemporaryItems()
        load()
    }

    var rootItems: [ProjectBrowserRecord] {
        ProjectBrowserPolicy.rootItems(projects: projects, folders: folders)
    }
    func folder(_ id: UUID) -> ProjectFolder? { folders.first { $0.id == id } }
    func projects(in id: UUID) -> [NarabiProject] {
        ProjectBrowserPolicy.projects(in: id, projects: projects)
    }
    func searchItems(_ query: String) -> [ProjectBrowserRecord] {
        ProjectBrowserPolicy.searchItems(query, projects: projects, folders: folders)
    }
    func add(_ project: NarabiProject) {
        var p = project
        p.folderID = nil
        p.browserOrder = nextRootOrder()
        projects.append(p)
        save()
    }
    func project(id: UUID) -> NarabiProject? { projects.first { $0.id == id } }
    func update(_ project: NarabiProject) {
        guard let i = projects.firstIndex(where: { $0.id == project.id }) else { return }
        var v = project
        v.updatedAt = Date()
        projects[i] = v
        scheduleSave()
    }
    func delete(id: UUID) {
        projects.removeAll { $0.id == id }
        save()
    }
    func createFolder(name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        folders.append(ProjectFolder(name: n, browserOrder: nextRootOrder()))
        save()
    }
    func renameFolder(id: UUID, name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, let i = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[i].name = n
        save()
    }
    func renameProject(id: UUID, name: String) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].outputName = name
        projects[i].updatedAt = Date()
        save()
    }
    func duplicate(items: [String]) {
        ProjectBrowserMutationPolicy.duplicate(
            tokens: items, projects: &projects, folders: &folders)
        save()
    }
    func move(items: [String], to destination: UUID?, before: String? = nil) {
        ProjectBrowserMovementPolicy.move(
            tokens: items, to: destination, projects: &projects, folders: &folders)
        save()
    }
    func delete(items: [String]) {
        ProjectBrowserMutationPolicy.delete(
            tokens: items, projects: &projects, folders: &folders)
        save()
    }

    func relocateDragged(
        items tokens: [String], to folderID: UUID?, target targetToken: String, placeAfter: Bool
    ) {
        ProjectBrowserMovementPolicy.relocateDragged(
            tokens: tokens, to: folderID, target: targetToken, placeAfter: placeAfter,
            projects: &projects, folders: &folders)
        save()
    }

    func reorder(items tokens: [String], in folderID: UUID?, target targetToken: String, placeAfter: Bool) {
        ProjectBrowserMovementPolicy.reorder(
            tokens: tokens, in: folderID, target: targetToken, placeAfter: placeAfter,
            projects: &projects, folders: &folders)
        save()
    }

    private func nextRootOrder() -> Int {
        max(
            folders.map(\.browserOrder).max() ?? -1,
            projects.filter { $0.folderID == nil }.map(\.browserOrder).max() ?? -1) + 1
    }
    private func shift(after: Int, folderID: UUID?, excluding: UUID) {
        for i in projects.indices
        where projects[i].folderID == folderID && projects[i].id != excluding
            && projects[i].browserOrder > after
        { projects[i].browserOrder += 1 }
    }
    private func shiftRoot(after: Int, excluding: UUID) {
        for i in folders.indices where folders[i].id != excluding && folders[i].browserOrder > after {
            folders[i].browserOrder += 1
        }
        for i in projects.indices where projects[i].folderID == nil && projects[i].browserOrder > after {
            projects[i].browserOrder += 1
        }
    }
    private func normalizeOrders() {
        ProjectBrowserPolicy.normalizeOrders(projects: &projects, folders: &folders)
    }
    private func save() {
        persistenceGeneration += 1
        let requestedGeneration = persistenceGeneration
        saveDebounceTask?.cancel()
        saveDebounceTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 180_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled,
                requestedGeneration == persistenceGeneration
            else { return }
            requestPersistence()
        }
    }

    private func requestPersistence() {
        persistenceRequested = true
        guard persistenceWorkerTask == nil else { return }
        persistenceWorkerTask = Task { @MainActor in
            await persistenceLoop()
        }
    }

    private func persistenceLoop() async {
        while persistenceRequested {
            persistenceRequested = false
            let projectSnapshot = projects
            let folderSnapshot = folders
            let rootURL = storageRootURL
            let folderURL = foldersURL
            let folderBackupURL = foldersBackupURL
            let previousRevisions = persistedProjectRevisions
            do {
                let next = try await Task.detached(priority: .utility) {
                    try ProjectPersistence.save(
                        projects: projectSnapshot, folders: folderSnapshot, root: rootURL,
                        foldersURL: folderURL, foldersBackupURL: folderBackupURL,
                        previousRevisions: previousRevisions)
                }.value
                persistedProjectRevisions = next
            } catch {
                let nsError = error as NSError
                persistenceErrorMessage =
                    nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError
                    ? L10n.text(
                        "error.storageFull",
                        "端末の空き容量が不足しています。不要なデータを整理してから、もう一度お試しください。"
                    )
                    : L10n.text(
                        "error.saveFailed",
                        "プロジェクトを保存できませんでした。空き容量を確認して、もう一度お試しください。"
                    )
                #if DEBUG
                print("Narabi persistence failed: \(error.localizedDescription)")
                #endif
            }
        }
        persistenceWorkerTask = nil
        if persistenceRequested { requestPersistence() }
    }

    private func scheduleSave() { save() }
    nonisolated private static func writeRecoverable(_ data: Data, primary: URL, backup: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: primary.path) {
            try? fm.removeItem(at: backup)
            try fm.copyItem(at: primary, to: backup)
        }
        do {
            try data.write(to: primary, options: .atomic)
        } catch {
            if !fm.fileExists(atPath: primary.path), fm.fileExists(atPath: backup.path) {
                try? fm.copyItem(at: backup, to: primary)
            }
            throw error
        }
    }
    private static func decodeRecovering<T: Decodable>(_ type: T.Type, primary: URL, backup: URL) -> T? {
        if let data = try? Data(contentsOf: primary), let value = try? JSONDecoder().decode(type, from: data)
        {
            return value
        }
        if let data = try? Data(contentsOf: backup), let value = try? JSONDecoder().decode(type, from: data) {
            try? data.write(to: primary, options: .atomic)
            return value
        }
        return nil
    }
    private func load() {
        let loaded = ProjectPersistence.load(
            root: storageRootURL, legacyProjects: saveURL, legacyProjectsBackup: saveBackupURL,
            legacyFolders: foldersURL, legacyFoldersBackup: foldersBackupURL)
        projects = loaded.projects
        folders = loaded.folders
        persistedProjectRevisions = loaded.revisions
        if folders.isEmpty && Set(projects.map(\.browserOrder)).count <= 1 {
            for index in projects.indices { projects[index].browserOrder = index }
        }
        normalizeOrders()
        if loaded.usedLegacyStore, !projects.isEmpty { requestPersistence() }
    }
}
