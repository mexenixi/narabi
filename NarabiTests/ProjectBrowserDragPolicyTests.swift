import CoreFoundation
import Testing

@testable import Narabi

@MainActor
struct ProjectBrowserDragPolicyTests {
    @Test func singleItemDragUsesOnlyPressedItem() {
        let project = NarabiProject(outputName: "One")
        let item = ProjectBrowserItem.project(project)
        let result = ProjectBrowserDragPolicy.dragTokens(
            itemID: project.id,
            itemToken: item.token,
            selectionMode: false,
            selection: [],
            items: [item]
        )
        #expect(result == [item.token])
    }

    @Test func selectedItemsKeepSelectionOrder() {
        let first = NarabiProject(outputName: "First")
        let second = NarabiProject(outputName: "Second")
        let items: [ProjectBrowserItem] = [.project(first), .project(second)]
        let result = ProjectBrowserDragPolicy.dragTokens(
            itemID: first.id,
            itemToken: items[0].token,
            selectionMode: true,
            selection: [second.id, first.id],
            items: items
        )
        #expect(result == [items[1].token, items[0].token])
    }

    @Test func unselectedPressedItemDoesNotDragOtherSelection() {
        let first = NarabiProject(outputName: "First")
        let second = NarabiProject(outputName: "Second")
        let items: [ProjectBrowserItem] = [.project(first), .project(second)]
        let result = ProjectBrowserDragPolicy.dragTokens(
            itemID: first.id,
            itemToken: items[0].token,
            selectionMode: true,
            selection: [second.id],
            items: items
        )
        #expect(result == [items[0].token])
    }

    @Test func rootHoverRequiresFolderAndTopZone() {
        #expect(ProjectBrowserDragPolicy.shouldReturnToRoot(insideFolder: true, pointY: 12))
        #expect(ProjectBrowserDragPolicy.shouldReturnToRoot(insideFolder: true, pointY: 13) == false)
        #expect(ProjectBrowserDragPolicy.shouldReturnToRoot(insideFolder: false, pointY: 0) == false)
    }

    @Test func folderEnterZoneUsesBothCellEdges() {
        #expect(ProjectBrowserDragPolicy.isFolderEnterZone(positionX: 72, cellWidth: 300))
        #expect(ProjectBrowserDragPolicy.isFolderEnterZone(positionX: 236, cellWidth: 300))
        #expect(ProjectBrowserDragPolicy.isFolderEnterZone(positionX: 150, cellWidth: 300) == false)
    }

    @Test func dropHalfDeterminesBeforeOrAfter() {
        #expect(ProjectBrowserDragPolicy.dropIsAfter(localY: 50, itemMidY: 50))
        #expect(ProjectBrowserDragPolicy.dropIsAfter(localY: 49.9, itemMidY: 50) == false)
    }
}
