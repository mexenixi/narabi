import Foundation
import Testing

@testable import Narabi

@MainActor
struct ImportSelectionPolicyTests {
    private func item(_ name: String) -> ImportItem {
        ImportItem(kind: .image, data: Data(name.utf8), displayName: name)
    }

    @Test func toggleAppendsNewSelectionInTapOrder() {
        let first = UUID()
        let second = UUID()
        let afterFirst = ImportSelectionPolicy.toggled(first, selected: [])
        let afterSecond = ImportSelectionPolicy.toggled(second, selected: afterFirst)
        #expect(afterSecond == [first, second])
    }

    @Test func toggleRemovesOnlyExistingSelection() {
        let first = UUID()
        let second = UUID()
        let result = ImportSelectionPolicy.toggled(first, selected: [first, second])
        #expect(result == [second])
    }

    @Test func moveMatchesListMoveAndKeepsSelectionOrderExternal() {
        let items = [item("A"), item("B"), item("C"), item("D")]
        let selected = [items[2].id, items[0].id]
        let moved = ImportSelectionPolicy.moved(
            items: items,
            fromOffsets: IndexSet(integer: 0),
            toOffset: 3
        )
        #expect(moved.map(\.displayName) == ["B", "C", "A", "D"])
        #expect(selected == [items[2].id, items[0].id])
    }

    @Test func deletingRowsRemovesDeletedIDsFromSelectionOnly() {
        let items = [item("A"), item("B"), item("C"), item("D")]
        let selected = [items[2].id, items[0].id, items[3].id]
        let state = ImportSelectionPolicy.deleting(
            offsets: IndexSet([0, 2]),
            items: items,
            selected: selected
        )
        #expect(state.items.map(\.displayName) == ["B", "D"])
        #expect(state.selected == [items[3].id])
    }

    @Test func deletingUnselectedRowPreservesSelectionOrder() {
        let items = [item("A"), item("B"), item("C")]
        let selected = [items[2].id, items[0].id]
        let state = ImportSelectionPolicy.deleting(
            offsets: IndexSet(integer: 1),
            items: items,
            selected: selected
        )
        #expect(state.items.map(\.displayName) == ["A", "C"])
        #expect(state.selected == selected)
    }

    @Test func deletingSelectedRemovesEverySelectedItemAndClearsSelection() {
        let items = [item("A"), item("B"), item("C"), item("D")]
        let selected = [items[2].id, items[0].id]
        let state = ImportSelectionPolicy.deletingSelected(
            items: items,
            selected: selected
        )
        #expect(state.items.map(\.displayName) == ["B", "D"])
        #expect(state.selected.isEmpty)
    }

    @Test func deletingUnknownSelectionLeavesItemsAndClearsSelection() {
        let items = [item("A"), item("B")]
        let state = ImportSelectionPolicy.deletingSelected(
            items: items,
            selected: [UUID()]
        )
        #expect(state.items == items)
        #expect(state.selected.isEmpty)
    }

    @Test func deletingEmptyOffsetsLeavesStateUnchanged() {
        let items = [item("A"), item("B")]
        let selected = [items[1].id]
        let state = ImportSelectionPolicy.deleting(
            offsets: [],
            items: items,
            selected: selected
        )
        #expect(state.items == items)
        #expect(state.selected == selected)
    }
}
