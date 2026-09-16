import CoreGraphics
import Foundation

enum ProjectBrowserDragPolicy {
    static func dragTokens(
        itemID: UUID,
        itemToken: String,
        selectionMode: Bool,
        selection: [UUID],
        items: [ProjectBrowserItem]
    ) -> [String] {
        guard selectionMode, selection.contains(itemID) else {
            return [itemToken]
        }
        return selection.compactMap { id in
            items.first { $0.id == id }?.token
        }
    }

    static func shouldReturnToRoot(insideFolder: Bool, pointY: CGFloat) -> Bool {
        insideFolder && pointY <= 12
    }

    static func isFolderEnterZone(positionX: CGFloat, cellWidth: CGFloat) -> Bool {
        positionX <= 72 || positionX >= cellWidth - 64
    }

    static func dropIsAfter(localY: CGFloat, itemMidY: CGFloat) -> Bool {
        localY >= itemMidY
    }
}
