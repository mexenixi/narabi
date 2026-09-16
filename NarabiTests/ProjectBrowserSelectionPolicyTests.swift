import Foundation
import Testing

@testable import Narabi

@MainActor
struct ProjectBrowserSelectionPolicyTests {
    @Test func toggleAddsNewSelectionAtTheEnd() {
        let first = UUID()
        let second = UUID()
        var selection = [first]

        ProjectBrowserSelectionPolicy.toggle(second, selection: &selection)

        #expect(selection == [first, second])
    }

    @Test func toggleRemovesOnlyTheExistingSelection() {
        let first = UUID()
        let second = UUID()
        let third = UUID()
        var selection = [first, second, third]

        ProjectBrowserSelectionPolicy.toggle(second, selection: &selection)

        #expect(selection == [first, third])
    }

    @Test func selectedItemsFollowSelectionOrderAndIgnoreMissingIDs() {
        let first = project("First")
        let second = project("Second")
        let missing = UUID()
        let items: [ProjectBrowserItem] = [.project(first), .project(second)]

        let selected = ProjectBrowserSelectionPolicy.selectedItems(
            from: items,
            selection: [second.id, missing, first.id]
        )

        #expect(selected.map(\.id) == [second.id, first.id])
    }

    @Test func normalModeUsesOnlyThePressedItem() {
        let first = ProjectBrowserItem.project(project("First"))
        let second = ProjectBrowserItem.project(project("Second"))

        let targets = ProjectBrowserSelectionPolicy.actionTargets(
            pressed: first,
            selectionMode: false,
            items: [first, second],
            selection: [second.id]
        )

        #expect(targets.map(\.id) == [first.id])
    }

    @Test func selectionModeUsesSelectedItemsWithoutAddingThePressedItem() {
        let first = ProjectBrowserItem.project(project("First"))
        let second = ProjectBrowserItem.project(project("Second"))
        let third = ProjectBrowserItem.project(project("Third"))

        let targets = ProjectBrowserSelectionPolicy.actionTargets(
            pressed: third,
            selectionMode: true,
            items: [first, second, third],
            selection: [second.id, first.id]
        )

        #expect(targets.map(\.id) == [second.id, first.id])
    }

    @Test func onlyProjectsCanMove() {
        let projectItem = ProjectBrowserItem.project(project("Project"))
        let another = ProjectBrowserItem.project(project("Another"))
        let folder = ProjectBrowserItem.folder(ProjectFolder(name: "Folder", browserOrder: 0))

        #expect(ProjectBrowserSelectionPolicy.canMove([projectItem, another]))
        #expect(ProjectBrowserSelectionPolicy.canMove([projectItem, folder]) == false)
        #expect(ProjectBrowserSelectionPolicy.canMove([]) == false)
    }

    @Test func folderDetectionDistinguishesDeleteWarnings() {
        let projectItem = ProjectBrowserItem.project(project("Project"))
        let folder = ProjectBrowserItem.folder(ProjectFolder(name: "Folder", browserOrder: 0))

        #expect(ProjectBrowserSelectionPolicy.containsFolder([projectItem]) == false)
        #expect(ProjectBrowserSelectionPolicy.containsFolder([projectItem, folder]))
    }

    private func project(_ name: String) -> NarabiProject {
        var value = NarabiProject()
        value.outputName = name
        return value
    }
}
