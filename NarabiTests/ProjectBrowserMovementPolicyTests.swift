import Foundation
import Testing

@testable import Narabi

@Suite("Project browser movement policy")
struct ProjectBrowserMovementPolicyTests {
    @Test func moveProjectsToFolderPreservesInputOrderAtEnd() {
        let folder = ProjectFolder(name: "Folder", browserOrder: 0)
        let existing = project("Existing", folderID: folder.id, order: 0)
        let first = project("First", order: 0)
        let second = project("Second", order: 1)
        var projects = [existing, first, second]
        var folders = [folder]
        ProjectBrowserMovementPolicy.move(
            tokens: [token(first), token(second)], to: folder.id,
            projects: &projects, folders: &folders)
        let result = ProjectBrowserPolicy.projects(in: folder.id, projects: projects)
        #expect(result.map(\.outputName) == ["Existing", "First", "Second"])
    }

    @Test func moveProjectBackToRootPlacesItAtEnd() {
        let folder = ProjectFolder(name: "Folder", browserOrder: 0)
        let root = project("Root", order: 1)
        let nested = project("Nested", folderID: folder.id)
        var projects = [root, nested]
        var folders = [folder]
        ProjectBrowserMovementPolicy.move(
            tokens: [token(nested)], to: nil, projects: &projects, folders: &folders)
        let result = ProjectBrowserPolicy.rootItems(projects: projects, folders: folders)
        #expect(
            result.compactMap { $0.project?.outputName ?? $0.folder?.name } == ["Folder", "Root", "Nested"])
    }

    @Test func relocateDraggedUsesEndMarkerForLastPosition() {
        let first = project("First", order: 0)
        let second = project("Second", order: 1)
        let third = project("Third", order: 2)
        var projects = [first, second, third]
        var folders: [ProjectFolder] = []
        ProjectBrowserMovementPolicy.relocateDragged(
            tokens: [token(first)], to: nil, target: "__end__", placeAfter: false,
            projects: &projects, folders: &folders)
        let result = ProjectBrowserPolicy.rootItems(projects: projects, folders: folders)
        #expect(result.compactMap { $0.project?.outputName } == ["Second", "Third", "First"])
    }

    @Test func relocateDraggedUnknownTargetAlsoUsesLastPosition() {
        let first = project("First", order: 0)
        let second = project("Second", order: 1)
        var projects = [first, second]
        var folders: [ProjectFolder] = []
        ProjectBrowserMovementPolicy.relocateDragged(
            tokens: [token(first)], to: nil, target: "unknown", placeAfter: false,
            projects: &projects, folders: &folders)
        let result = ProjectBrowserPolicy.rootItems(projects: projects, folders: folders)
        #expect(result.compactMap { $0.project?.outputName } == ["Second", "First"])
    }

    @Test func foldersCannotBeMovedInsideAnotherFolder() {
        let source = ProjectFolder(name: "Source", browserOrder: 0)
        let destination = ProjectFolder(name: "Destination", browserOrder: 1)
        var projects: [NarabiProject] = []
        var folders = [source, destination]
        ProjectBrowserMovementPolicy.relocateDragged(
            tokens: [folderToken(source)], to: destination.id, target: "__end__", placeAfter: false,
            projects: &projects, folders: &folders)
        #expect(folders == [source, destination])
    }

    @Test func reorderMultipleProjectsKeepsTheirExistingRelativeOrder() {
        let first = project("First", order: 0)
        let second = project("Second", order: 1)
        let third = project("Third", order: 2)
        let fourth = project("Fourth", order: 3)
        var projects = [first, second, third, fourth]
        var folders: [ProjectFolder] = []
        ProjectBrowserMovementPolicy.reorder(
            tokens: [token(first), token(second)], in: nil, target: token(third), placeAfter: true,
            projects: &projects, folders: &folders)
        let result = ProjectBrowserPolicy.rootItems(projects: projects, folders: folders)
        #expect(result.compactMap { $0.project?.outputName } == ["Third", "First", "Second", "Fourth"])
    }

    @Test func reorderWithMissingTargetMakesNoChange() {
        let first = project("First", order: 0)
        let second = project("Second", order: 1)
        var projects = [first, second]
        var folders: [ProjectFolder] = []
        ProjectBrowserMovementPolicy.reorder(
            tokens: [token(first)], in: nil, target: "missing", placeAfter: true,
            projects: &projects, folders: &folders)
        #expect(projects == [first, second])
    }

    private func project(_ name: String, folderID: UUID? = nil, order: Int = 0) -> NarabiProject {
        var value = NarabiProject()
        value.outputName = name
        value.folderID = folderID
        value.browserOrder = order
        return value
    }
    private func token(_ project: NarabiProject) -> String {
        ProjectBrowserMutationPolicy.Token.project(project.id).rawValue
    }
    private func folderToken(_ folder: ProjectFolder) -> String {
        ProjectBrowserMutationPolicy.Token.folder(folder.id).rawValue
    }
}
