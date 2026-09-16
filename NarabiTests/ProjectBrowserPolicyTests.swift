import Foundation
import Testing
@testable import Narabi

@Suite("Project browser policy")
struct ProjectBrowserPolicyTests {
    @Test func rootItemsMixFoldersAndRootProjectsByOrder() {
        let folder = ProjectFolder(name: "Folder", browserOrder: 1)
        let nested = project("Nested", folderID: folder.id, order: 0)
        let last = project("Last", order: 2)
        let first = project("First", order: 0)
        let records = ProjectBrowserPolicy.rootItems(projects: [nested, last, first], folders: [folder])
        #expect(records.count == 3)
        #expect(records[0].project?.id == first.id)
        #expect(records[1].folder?.id == folder.id)
        #expect(records[2].project?.id == last.id)
    }

    @Test func folderProjectsAreFilteredAndSorted() {
        let folderID = UUID()
        let second = project("Second", folderID: folderID, order: 1)
        let first = project("First", folderID: folderID, order: 0)
        let other = project("Other", folderID: UUID(), order: 0)
        let result = ProjectBrowserPolicy.projects(in: folderID, projects: [second, other, first])
        #expect(result.map(\.id) == [first.id, second.id])
    }

    @Test func searchIgnoresCaseDiacriticsAndWidth() {
        let projects = [project("Résumé"), project("ＡＢＣ Report")]
        let accent = ProjectBrowserPolicy.searchItems(
            "resume", projects: projects, folders: [], locale: Locale(identifier: "en_US_POSIX"))
        let width = ProjectBrowserPolicy.searchItems(
            "abc", projects: projects, folders: [], locale: Locale(identifier: "en_US_POSIX"))
        #expect(accent.map { $0.project?.outputName } == ["Résumé"])
        #expect(width.map { $0.project?.outputName } == ["ＡＢＣ Report"])
    }

    @Test func searchFindsProjectsThroughFolderName() {
        let folder = ProjectFolder(name: "資格資料", browserOrder: 0)
        let nested = project("2026", folderID: folder.id)
        let result = ProjectBrowserPolicy.searchItems(
            "資格", projects: [nested], folders: [folder], locale: Locale(identifier: "ja_JP"))
        #expect(result.contains { $0.folder?.id == folder.id })
        #expect(result.contains { $0.project?.id == nested.id })
    }

    @Test func normalizeOrdersCompactsRootAndFolderOrders() throws {
        var folders = [
            ProjectFolder(name: "Second", browserOrder: 20),
            ProjectFolder(name: "First", browserOrder: 5),
        ]
        let secondFolderID = folders[0].id
        var projects = [
            project("Root", order: 10),
            project("Nested B", folderID: secondFolderID, order: 9),
            project("Nested A", folderID: secondFolderID, order: 3),
        ]
        ProjectBrowserPolicy.normalizeOrders(projects: &projects, folders: &folders)
        let root = ProjectBrowserPolicy.rootItems(projects: projects, folders: folders)
        let rootOrders = root.map { $0.folder?.browserOrder ?? $0.project?.browserOrder ?? -1 }
        #expect(rootOrders == [0, 1, 2])
        let nested = ProjectBrowserPolicy.projects(in: secondFolderID, projects: projects)
        #expect(nested.map(\.outputName) == ["Nested A", "Nested B"])
        #expect(nested.map(\.browserOrder) == [0, 1])
    }

    private func project(_ name: String, folderID: UUID? = nil, order: Int = 0) -> NarabiProject {
        var value = NarabiProject()
        value.outputName = name
        value.folderID = folderID
        value.browserOrder = order
        return value
    }
}
