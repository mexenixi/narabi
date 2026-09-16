import Testing
import UIKit

@testable import Narabi

@MainActor
struct WorkspaceDragPolicyTests {
    @Test func closestAreaUsesTrayTopBoundary() {
        let tray = CGRect(x: 0, y: 500, width: 300, height: 116)
        #expect(WorkspaceDragPolicy.closestArea(point: CGPoint(x: 0, y: 499), trayFrame: tray) == .editor)
        #expect(WorkspaceDragPolicy.closestArea(point: CGPoint(x: 0, y: 500), trayFrame: tray) == .tray)
    }

    @Test func lastTrayItemDropAtEndNormalizes() {
        #expect(
            WorkspaceDragPolicy.normalizedTrayDestination(
                dragStartIndex: 4,
                trayCount: 5,
                destination: 5
            ) == 4
        )
        #expect(
            WorkspaceDragPolicy.normalizedTrayDestination(
                dragStartIndex: 2,
                trayCount: 5,
                destination: 5
            ) == 5
        )
    }

    @Test func trayAutoScrollUsesHorizontalEdges() {
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 116)
        let left = WorkspaceDragPolicy.autoScrollVelocity(
            area: .tray,
            trayCollapsed: false,
            contentOffset: .zero,
            bounds: bounds,
            localPoint: CGPoint(x: 0, y: 50)
        )
        let center = WorkspaceDragPolicy.autoScrollVelocity(
            area: .tray,
            trayCollapsed: false,
            contentOffset: .zero,
            bounds: bounds,
            localPoint: CGPoint(x: 150, y: 50)
        )
        let right = WorkspaceDragPolicy.autoScrollVelocity(
            area: .tray,
            trayCollapsed: false,
            contentOffset: .zero,
            bounds: bounds,
            localPoint: CGPoint(x: 300, y: 50)
        )
        #expect(left == CGPoint(x: -14, y: 0))
        #expect(center == .zero)
        #expect(right == CGPoint(x: 14, y: 0))
    }

    @Test func editorAutoScrollRequiresCollapsedTray() {
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 600)
        let expanded = WorkspaceDragPolicy.autoScrollVelocity(
            area: .editor,
            trayCollapsed: false,
            contentOffset: .zero,
            bounds: bounds,
            localPoint: CGPoint(x: 150, y: 0)
        )
        let collapsed = WorkspaceDragPolicy.autoScrollVelocity(
            area: .editor,
            trayCollapsed: true,
            contentOffset: .zero,
            bounds: bounds,
            localPoint: CGPoint(x: 150, y: 0)
        )
        #expect(expanded == .zero)
        #expect(collapsed == CGPoint(x: 0, y: -14))
    }

    @Test func contentOffsetClampsToInsetsAndContentBounds() {
        let insets = UIEdgeInsets(top: 20, left: 10, bottom: 30, right: 40)
        let minimum = WorkspaceDragPolicy.clampedContentOffset(
            current: CGPoint(x: -10, y: -20),
            velocity: CGPoint(x: -100, y: -100),
            contentSize: CGSize(width: 1000, height: 1200),
            bounds: CGRect(x: 0, y: 0, width: 300, height: 600),
            adjustedInsets: insets
        )
        let maximum = WorkspaceDragPolicy.clampedContentOffset(
            current: CGPoint(x: 700, y: 600),
            velocity: CGPoint(x: 100, y: 100),
            contentSize: CGSize(width: 1000, height: 1200),
            bounds: CGRect(x: 0, y: 0, width: 300, height: 600),
            adjustedInsets: insets
        )
        #expect(minimum == CGPoint(x: -10, y: -20))
        #expect(maximum == CGPoint(x: 740, y: 630))
    }
}
