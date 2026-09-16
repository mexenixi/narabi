import Foundation

/// Persists projects independently so one edit never re-encodes every project.
/// The legacy aggregate JSON remains a migration and emergency-recovery source.
nonisolated enum ProjectPersistence {
    struct Manifest: Codable {
        var formatVersion: Int
        var projectIDs: [UUID]
        var savedAt: Date
    }

    struct Revision: Equatable, Sendable {
        let updatedAt: Date
        let folderID: UUID?
        let browserOrder: Int
        let pages: Int
        let tray: Int
        let deleted: Int
        let approximateBytes: Int64

        init(_ project: NarabiProject) {
            updatedAt = project.updatedAt
            folderID = project.folderID
            browserOrder = project.browserOrder
            pages = project.pages.count
            tray = project.tray.count
            deleted = project.deleted.count
            approximateBytes = project.approximateBytes
        }
    }

    struct LoadedState {
        var projects: [NarabiProject]
        var folders: [ProjectFolder]
        var revisions: [UUID: Revision]
        var usedLegacyStore: Bool
    }

    static func load(
        root: URL,
        legacyProjects: URL,
        legacyProjectsBackup: URL,
        legacyFolders: URL,
        legacyFoldersBackup: URL
    ) -> LoadedState {
        let folders =
            decodeRecovering(
                [ProjectFolder].self,
                primary: legacyFolders,
                backup: legacyFoldersBackup
            ) ?? []
        let projectsRoot = root.appendingPathComponent("Projects", isDirectory: true)
        let manifestURL = root.appendingPathComponent("projectIndex.json")
        let manifestBackupURL = root.appendingPathComponent("projectIndex.backup.json")

        guard
            let manifest = decodeRecovering(
                Manifest.self,
                primary: manifestURL,
                backup: manifestBackupURL
            )
        else {
            return loadLegacy(
                projects: legacyProjects,
                backup: legacyProjectsBackup,
                folders: folders
            )
        }

        var loadedProjects: [NarabiProject] = []
        loadedProjects.reserveCapacity(manifest.projectIDs.count)
        for projectID in manifest.projectIDs {
            let directory = projectsRoot.appendingPathComponent(
                projectID.uuidString,
                isDirectory: true
            )
            guard
                let project = decodeRecovering(
                    NarabiProject.self,
                    primary: directory.appendingPathComponent("project.json"),
                    backup: directory.appendingPathComponent("project.backup.json")
                )
            else {
                return loadLegacy(
                    projects: legacyProjects,
                    backup: legacyProjectsBackup,
                    folders: folders
                )
            }
            loadedProjects.append(project)
        }
        return LoadedState(
            projects: loadedProjects,
            folders: folders,
            revisions: revisions(for: loadedProjects),
            usedLegacyStore: false
        )
    }

    static func save(
        projects: [NarabiProject],
        folders: [ProjectFolder],
        root: URL,
        foldersURL: URL,
        foldersBackupURL: URL,
        previousRevisions: [UUID: Revision]
    ) throws -> [UUID: Revision] {
        let fileManager = FileManager.default
        let projectsRoot = root.appendingPathComponent("Projects", isDirectory: true)
        try fileManager.createDirectory(
            at: projectsRoot,
            withIntermediateDirectories: true
        )
        let nextRevisions = revisions(for: projects)

        for project in projects where previousRevisions[project.id] != nextRevisions[project.id] {
            try autoreleasepool {
                let directory = projectsRoot.appendingPathComponent(
                    project.id.uuidString,
                    isDirectory: true
                )
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                let data = try JSONEncoder().encode(project)
                try writeRecoverable(
                    data,
                    primary: directory.appendingPathComponent("project.json"),
                    backup: directory.appendingPathComponent("project.backup.json")
                )
            }
        }

        let manifest = Manifest(
            formatVersion: 2,
            projectIDs: projects.map(\.id),
            savedAt: Date()
        )
        try writeRecoverable(
            try JSONEncoder().encode(manifest),
            primary: root.appendingPathComponent("projectIndex.json"),
            backup: root.appendingPathComponent("projectIndex.backup.json")
        )
        try writeRecoverable(
            try JSONEncoder().encode(folders),
            primary: foldersURL,
            backup: foldersBackupURL
        )

        let liveProjectIDs = Set(projects.map { $0.id.uuidString })
        if let directories = try? fileManager.contentsOfDirectory(
            at: projectsRoot,
            includingPropertiesForKeys: nil
        ) {
            for directory in directories
            where !liveProjectIDs.contains(directory.lastPathComponent) {
                try? fileManager.removeItem(at: directory)
            }
        }
        return nextRevisions
    }

    static func revisions(for projects: [NarabiProject]) -> [UUID: Revision] {
        Dictionary(
            uniqueKeysWithValues: projects.map { ($0.id, Revision($0)) }
        )
    }

    private static func loadLegacy(
        projects: URL,
        backup: URL,
        folders: [ProjectFolder]
    ) -> LoadedState {
        let loadedProjects =
            decodeRecovering(
                [NarabiProject].self,
                primary: projects,
                backup: backup
            ) ?? []
        return LoadedState(
            projects: loadedProjects,
            folders: folders,
            revisions: [:],
            usedLegacyStore: true
        )
    }

    private static func writeRecoverable(
        _ data: Data,
        primary: URL,
        backup: URL
    ) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: primary.path) {
            try? fileManager.removeItem(at: backup)
            try fileManager.copyItem(at: primary, to: backup)
        }
        do {
            try data.write(to: primary, options: .atomic)
        } catch {
            if !fileManager.fileExists(atPath: primary.path),
                fileManager.fileExists(atPath: backup.path)
            {
                try? fileManager.copyItem(at: backup, to: primary)
            }
            throw error
        }
    }

    private static func decodeRecovering<T: Decodable>(
        _ type: T.Type,
        primary: URL,
        backup: URL
    ) -> T? {
        if let data = try? Data(contentsOf: primary),
            let value = try? JSONDecoder().decode(type, from: data)
        {
            return value
        }
        if let data = try? Data(contentsOf: backup),
            let value = try? JSONDecoder().decode(type, from: data)
        {
            try? data.write(to: primary, options: .atomic)
            return value
        }
        return nil
    }
}
