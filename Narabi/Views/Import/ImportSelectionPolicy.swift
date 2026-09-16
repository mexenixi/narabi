import Foundation
import SwiftUI

enum ImportSelectionPolicy {
    struct State: Equatable {
        let items: [ImportItem]
        let selected: [UUID]
    }

    static func toggled(_ id: UUID, selected: [UUID]) -> [UUID] {
        var result = selected
        if let index = result.firstIndex(of: id) {
            result.remove(at: index)
        } else {
            result.append(id)
        }
        return result
    }

    static func moved(
        items: [ImportItem],
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) -> [ImportItem] {
        var result = items
        result.move(fromOffsets: source, toOffset: destination)
        return result
    }

    static func deleting(
        offsets: IndexSet,
        items: [ImportItem],
        selected: [UUID]
    ) -> State {
        let deletedIDs = Set(
            offsets.compactMap { index in
                items.indices.contains(index) ? items[index].id : nil
            })
        var remainingItems = items
        remainingItems.remove(atOffsets: offsets)
        return State(
            items: remainingItems,
            selected: selected.filter { !deletedIDs.contains($0) }
        )
    }

    static func deletingSelected(
        items: [ImportItem],
        selected: [UUID]
    ) -> State {
        let selectedIDs = Set(selected)
        return State(
            items: items.filter { !selectedIDs.contains($0.id) },
            selected: []
        )
    }
}
