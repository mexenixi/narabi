import Foundation
import Testing
@testable import Narabi

@Suite("Project persistence integration", .serialized)
struct ProjectPersistenceIntegrationTests {
    @Test func savesAndLoadsIndependentProjectsAndFolders() throws {
        let env = try Environment()
        defer { env.remove() }
        let folder = ProjectFolder(name: "Folder", browserOrder: 0)
        var first = project(name: "First", order: 0)
        first.folderID = folder.id
        let second = project(name: "Second", order: 1)

        let revisions = try ProjectPersistence.save(
            projects: [first, second], folders: [folder], root: env.root,
            foldersURL: env.folders, foldersBackupURL: env.foldersBackup,
            previousRevisions: [:])
        let loaded = ProjectPersistence.load(
            root: env.root, legacyProjects: env.legacyProjects,
            legacyProjectsBackup: env.legacyProjectsBackup,
            legacyFolders: env.folders, legacyFoldersBackup: env.foldersBackup)

        #expect(loaded.usedLegacyStore == false)
        #expect(loaded.projects == [first, second])
        #expect(loaded.folders == [folder])
        #expect(loaded.revisions == revisions)
    }

    @Test func writesManifestInProjectOrder() throws {
        let env = try Environment()
        defer { env.remove() }
        let first = project(name: "First", order: 5)
        let second = project(name: "Second", order: 1)
        _ = try ProjectPersistence.save(
            projects: [second, first], folders: [], root: env.root,
            foldersURL: env.folders, foldersBackupURL: env.foldersBackup,
            previousRevisions: [:])
        let data = try Data(contentsOf: env.root.appendingPathComponent("projectIndex.json"))
        let manifest = try JSONDecoder().decode(ProjectPersistence.Manifest.self, from: data)
        #expect(manifest.formatVersion == 2)
        #expect(manifest.projectIDs == [second.id, first.id])
    }

    @Test func createsBackupBeforeReplacingProject() throws {
        let env = try Environment()
        defer { env.remove() }
        var value = project(name: "Before", order: 0)
        var revisions = try ProjectPersistence.save(
            projects: [value], folders: [], root: env.root,
            foldersURL: env.folders, foldersBackupURL: env.foldersBackup,
            previousRevisions: [:])
        value.outputName = "After"
        value.updatedAt = value.updatedAt.addingTimeInterval(10)
        revisions = try ProjectPersistence.save(
            projects: [value], folders: [], root: env.root,
            foldersURL: env.folders, foldersBackupURL: env.foldersBackup,
            previousRevisions: revisions)
        let directory = env.root.appendingPathComponent("Projects/\(value.id.uuidString)")
        let backupData = try Data(contentsOf: directory.appendingPathComponent("project.backup.json"))
        let backup = try JSONDecoder().decode(NarabiProject.self, from: backupData)
        #expect(backup.outputName == "Before")
        #expect(revisions[value.id] == ProjectPersistence.Revision(value))
    }

    @Test func recoversCorruptPrimaryProjectFromBackup() throws {
        let env = try Environment()
        defer { env.remove() }
        var value = project(name: "Before", order: 0)
        var revisions = try ProjectPersistence.save(
            projects: [value], folders: [], root: env.root,
            foldersURL: env.folders, foldersBackupURL: env.foldersBackup,
            previousRevisions: [:])
        value.outputName = "After"
        value.updatedAt = value.updatedAt.addingTimeInterval(10)
        revisions = try ProjectPersistence.save(
            projects: [value], folders: [], root: env.root,
            foldersURL: env.folders, foldersBackupURL: env.foldersBackup,
            previousRevisions: revisions)
        let directory = env.root.appendingPathComponent("Projects/\(value.id.uuidString)")
        try Data("broken".utf8).write(to: directory.appendingPathComponent("project.json"))
        let loaded = ProjectPersistence.load(
            root: env.root, legacyProjects: env.legacyProjects,
            legacyProjectsBackup: env.legacyProjectsBackup,
            legacyFolders: env.folders, legacyFoldersBackup: env.foldersBackup)
        #expect(loaded.projects.count == 1)
        #expect(loaded.projects[0].outputName == "Before")
        _ = revisions
    }

    @Test func removesProjectDirectoryNoLongerInManifest() throws {
        let env = try Environment()
        defer { env.remove() }
        let first = project(name: "First", order: 0)
        let second = project(name: "Second", order: 1)
        let revisions = try ProjectPersistence.save(
            projects: [first, second], folders: [], root: env.root,
            foldersURL: env.folders, foldersBackupURL: env.foldersBackup,
            previousRevisions: [:])
        _ = try ProjectPersistence.save(
            projects: [first], folders: [], root: env.root,
            foldersURL: env.folders, foldersBackupURL: env.foldersBackup,
            previousRevisions: revisions)
        let removed = env.root.appendingPathComponent("Projects/\(second.id.uuidString)")
        #expect(FileManager.default.fileExists(atPath: removed.path) == false)
    }

    @Test func fallsBackToLegacyAggregateStoreWithoutManifest() throws {
        let env = try Environment()
        defer { env.remove() }
        let value = project(name: "Legacy", order: 0)
        let folder = ProjectFolder(name: "Legacy Folder", browserOrder: 0)
        try JSONEncoder().encode([value]).write(to: env.legacyProjects)
        try JSONEncoder().encode([folder]).write(to: env.folders)
        let loaded = ProjectPersistence.load(
            root: env.root, legacyProjects: env.legacyProjects,
            legacyProjectsBackup: env.legacyProjectsBackup,
            legacyFolders: env.folders, legacyFoldersBackup: env.foldersBackup)
        #expect(loaded.usedLegacyStore)
        #expect(loaded.projects == [value])
        #expect(loaded.folders == [folder])
        #expect(loaded.revisions.isEmpty)
    }

    @Test func revisionReflectsAllPersistenceRelevantCounts() {
        var value = project(name: "Revision", order: 9)
        value.approximateBytes = 1234
        value.pages = [page(1)]
        value.tray = [page(2), page(3)]
        value.deleted = [page(4), page(5), page(6)]
        let revision = ProjectPersistence.Revision(value)
        #expect(revision.browserOrder == 9)
        #expect(revision.pages == 1)
        #expect(revision.tray == 2)
        #expect(revision.deleted == 3)
        #expect(revision.approximateBytes == 1234)
    }

    private func project(name: String, order: Int) -> NarabiProject {
        var value = NarabiProject()
        value.outputName = name
        value.browserOrder = order
        value.updatedAt = Date(timeIntervalSince1970: Double(1000 + order))
        value.pages = [page(UInt8(order + 1))]
        return value
    }

    private func page(_ byte: UInt8) -> ProjectPage {
        ProjectPage(originalData: Data([byte]), renderedData: Data([byte]))
    }

    private struct Environment {
        let root: URL
        let legacyProjects: URL
        let legacyProjectsBackup: URL
        let folders: URL
        let foldersBackup: URL

        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent(
                "NarabiPersistenceTests-\(UUID().uuidString)", isDirectory: true)
            legacyProjects = root.appendingPathComponent("legacy-projects.json")
            legacyProjectsBackup = root.appendingPathComponent("legacy-projects.backup.json")
            folders = root.appendingPathComponent("folders.json")
            foldersBackup = root.appendingPathComponent("folders.backup.json")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }

        func remove() { try? FileManager.default.removeItem(at: root) }
    }
}
