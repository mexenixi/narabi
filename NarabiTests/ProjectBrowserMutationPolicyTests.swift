import Foundation
import Testing

@testable import Narabi

@Suite("Project browser mutation policy")
struct ProjectBrowserMutationPolicyTests {
    @Test func tokensRoundTripAndRejectInvalidValues() {
        let projectID = UUID()
        let folderID = UUID()
        #expect(ProjectBrowserMutationPolicy.Token("project:\(projectID.uuidString)") == .project(projectID))
        #expect(ProjectBrowserMutationPolicy.Token("folder:\(folderID.uuidString)") == .folder(folderID))
        #expect(ProjectBrowserMutationPolicy.Token("other:\(projectID.uuidString)") == nil)
        #expect(ProjectBrowserMutationPolicy.Token("project:not-a-uuid") == nil)
        #expect(ProjectBrowserMutationPolicy.Token("missing") == nil)
    }

    @Test func duplicatesOneProjectBesideItsOriginal() throws {
        let original = project("Original", order: 1)
        let after = project("After", order: 2)
        var projects = [original, after]
        var folders: [ProjectFolder] = []
        let newID = UUID()
        let date = Date(timeIntervalSince1970: 123)
        ProjectBrowserMutationPolicy.duplicate(
            tokens: ["project:\(original.id.uuidString)"], projects: &projects,
            folders: &folders, now: { date }, makeID: { newID })
        #expect(projects.count == 3)
        let copy = try #require(projects.first { $0.id == newID })
        #expect(copy.outputName == original.outputName)
        #expect(copy.browserOrder == 2)
        #expect(copy.updatedAt == date)
        #expect(projects.first { $0.id == after.id }?.browserOrder == 3)
    }

    @Test func duplicatesFolderAndItsChildrenIntoNewFolder() throws {
        let folder = ProjectFolder(name: "Folder", browserOrder: 0)
        let childA = project("A", folderID: folder.id, order: 0)
        let childB = project("B", folderID: folder.id, order: 1)
        let other = project("Other", folderID: UUID(), order: 0)
        var projects = [childA, childB, other]
        var folders = [folder]
        var ids = [UUID(), UUID(), UUID()]
        ProjectBrowserMutationPolicy.duplicate(
            tokens: ["folder:\(folder.id.uuidString)"], projects: &projects,
            folders: &folders, makeID: { ids.removeFirst() })
        #expect(folders.count == 2)
        let copyFolder = try #require(folders.first { $0.id != folder.id })
        let copies = projects.filter { $0.folderID == copyFolder.id }
            .sorted { $0.browserOrder < $1.browserOrder }
        #expect(copies.map(\.outputName) == ["A", "B"])
        #expect(Set(copies.map(\.id)).isDisjoint(with: [childA.id, childB.id]))
        #expect(projects.contains { $0.id == other.id })
    }

    @Test func deleteProjectLeavesOtherProjectsAndNormalizesOrder() {
        let first = project("First", order: 0)
        let removed = project("Removed", order: 4)
        let last = project("Last", order: 9)
        var projects = [first, removed, last]
        var folders: [ProjectFolder] = []
        ProjectBrowserMutationPolicy.delete(
            tokens: ["project:\(removed.id.uuidString)"],
            projects: &projects, folders: &folders)
        #expect(projects.map(\.id).contains(removed.id) == false)
        let root = ProjectBrowserPolicy.rootItems(projects: projects, folders: folders)
        #expect(root.map { $0.project?.browserOrder } == [0, 1])
    }

    @Test func deleteFolderAlsoDeletesOnlyItsChildren() {
        let removedFolder = ProjectFolder(name: "Removed", browserOrder: 0)
        let keptFolder = ProjectFolder(name: "Kept", browserOrder: 1)
        let removedChild = project("Removed child", folderID: removedFolder.id)
        let keptChild = project("Kept child", folderID: keptFolder.id)
        let root = project("Root")
        var projects = [removedChild, keptChild, root]
        var folders = [removedFolder, keptFolder]
        ProjectBrowserMutationPolicy.delete(
            tokens: ["folder:\(removedFolder.id.uuidString)"],
            projects: &projects, folders: &folders)
        #expect(folders.map(\.id) == [keptFolder.id])
        #expect(projects.contains { $0.id == removedChild.id } == false)
        #expect(projects.contains { $0.id == keptChild.id })
        #expect(projects.contains { $0.id == root.id })
    }

    @Test func invalidAndMissingTokensDoNothing() {
        let original = project("Original")
        var projects = [original]
        var folders: [ProjectFolder] = []
        ProjectBrowserMutationPolicy.duplicate(
            tokens: ["invalid", "project:\(UUID().uuidString)"],
            projects: &projects, folders: &folders)
        ProjectBrowserMutationPolicy.delete(
            tokens: ["invalid", "folder:\(UUID().uuidString)"],
            projects: &projects, folders: &folders)
        #expect(projects == [original])
        #expect(folders.isEmpty)
    }

    private func project(_ name: String, folderID: UUID? = nil, order: Int = 0) -> NarabiProject {
        var value = NarabiProject()
        value.outputName = name
        value.folderID = folderID
        value.browserOrder = order
        return value
    }
}
