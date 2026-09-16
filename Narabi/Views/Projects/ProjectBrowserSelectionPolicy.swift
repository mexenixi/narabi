import Foundation

@MainActor
enum ProjectBrowserSelectionPolicy {
    static func toggle(_ itemID: UUID, selection: inout [UUID]) {
        if let index = selection.firstIndex(of: itemID) {
            selection.remove(at: index)
        } else {
            selection.append(itemID)
        }
    }

    static func selectedItems(
        from items: [ProjectBrowserItem],
        selection: [UUID]
    ) -> [ProjectBrowserItem] {
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return selection.compactMap { itemsByID[$0] }
    }

    static func actionTargets(
        pressed item: ProjectBrowserItem,
        selectionMode: Bool,
        items: [ProjectBrowserItem],
        selection: [UUID]
    ) -> [ProjectBrowserItem] {
        selectionMode ? selectedItems(from: items, selection: selection) : [item]
    }

    static func canMove(_ items: [ProjectBrowserItem]) -> Bool {
        !items.isEmpty
            && items.allSatisfy {
                if case .project = $0 { return true }
                return false
            }
    }

    static func containsFolder(_ items: [ProjectBrowserItem]) -> Bool {
        items.contains {
            if case .folder = $0 { return true }
            return false
        }
    }
}
