import UIKit

enum WorkspaceDragPolicy {
    static func closestArea(point: CGPoint, trayFrame: CGRect) -> WorkspaceArea {
        point.y >= trayFrame.minY ? .tray : .editor
    }

    static func normalizedTrayDestination(
        dragStartIndex: Int,
        trayCount: Int,
        destination: Int
    ) -> Int {
        if dragStartIndex == trayCount - 1, destination == trayCount {
            return dragStartIndex
        }
        return destination
    }

    static func autoScrollVelocity(
        area: WorkspaceArea,
        trayCollapsed: Bool,
        contentOffset: CGPoint,
        bounds: CGRect,
        localPoint: CGPoint,
        edge: CGFloat = 44
    ) -> CGPoint {
        func speed(_ penetration: CGFloat) -> CGFloat {
            let progress = min(max(penetration / edge, 0), 1)
            return 2 + 12 * progress * progress
        }

        var velocity = CGPoint.zero
        if area == .tray {
            if localPoint.x < contentOffset.x + edge {
                velocity.x = -speed(contentOffset.x + edge - localPoint.x)
            } else if localPoint.x > contentOffset.x + bounds.width - edge {
                velocity.x = speed(localPoint.x - (contentOffset.x + bounds.width - edge))
            }
        } else if trayCollapsed {
            if localPoint.y < contentOffset.y + edge {
                velocity.y = -speed(contentOffset.y + edge - localPoint.y)
            } else if localPoint.y > contentOffset.y + bounds.height - edge {
                velocity.y = speed(localPoint.y - (contentOffset.y + bounds.height - edge))
            }
        }
        return velocity
    }

    static func clampedContentOffset(
        current: CGPoint,
        velocity: CGPoint,
        contentSize: CGSize,
        bounds: CGRect,
        adjustedInsets: UIEdgeInsets
    ) -> CGPoint {
        let maxX = max(0, contentSize.width - bounds.width + adjustedInsets.right)
        let minX = -adjustedInsets.left
        let maxY = max(
            -adjustedInsets.top,
            contentSize.height - bounds.height + adjustedInsets.bottom
        )
        let minY = -adjustedInsets.top
        return CGPoint(
            x: min(maxX, max(minX, current.x + velocity.x)),
            y: min(maxY, max(minY, current.y + velocity.y))
        )
    }
}
