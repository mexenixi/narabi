import CoreGraphics
import Testing

@testable import Narabi

struct WorkspaceLayoutPolicyTests {
    @Test func phoneAlwaysUsesThreeColumns() {
        #expect(WorkspaceLayoutPolicy.editorColumnCount(isPad: false, availableWidth: 320) == 3)
        #expect(WorkspaceLayoutPolicy.editorColumnCount(isPad: false, availableWidth: 1_500) == 3)
    }

    @Test func padBoundaryBelowSixHundredUsesFourColumns() {
        #expect(WorkspaceLayoutPolicy.editorColumnCount(isPad: true, availableWidth: 599.9) == 4)
    }

    @Test func padSixHundredBoundaryUsesFiveColumns() {
        #expect(WorkspaceLayoutPolicy.editorColumnCount(isPad: true, availableWidth: 600) == 5)
        #expect(WorkspaceLayoutPolicy.editorColumnCount(isPad: true, availableWidth: 849.9) == 5)
    }

    @Test func padEightHundredFiftyBoundaryUsesSixColumns() {
        #expect(WorkspaceLayoutPolicy.editorColumnCount(isPad: true, availableWidth: 850) == 6)
        #expect(WorkspaceLayoutPolicy.editorColumnCount(isPad: true, availableWidth: 1_099.9) == 6)
    }

    @Test func padElevenHundredBoundaryUsesSevenColumns() {
        #expect(WorkspaceLayoutPolicy.editorColumnCount(isPad: true, availableWidth: 1_100) == 7)
        #expect(WorkspaceLayoutPolicy.editorColumnCount(isPad: true, availableWidth: 1_349.9) == 7)
    }

    @Test func padThirteenHundredFiftyBoundaryUsesEightColumns() {
        #expect(WorkspaceLayoutPolicy.editorColumnCount(isPad: true, availableWidth: 1_350) == 8)
    }

    @Test func itemSizeSubtractsInsetsAndSpacing() {
        let size = WorkspaceLayoutPolicy.editorItemSize(
            availableWidth: 320,
            columns: 3,
            leftInset: 8,
            rightInset: 8,
            interitemSpacing: 8
        )
        #expect(size.width == 96)
    }

    @Test func itemHeightPreservesExistingAspectRatio() {
        let size = WorkspaceLayoutPolicy.editorItemSize(
            availableWidth: 320,
            columns: 3,
            leftInset: 8,
            rightInset: 8,
            interitemSpacing: 8
        )
        #expect(abs(size.height - size.width / 0.72) < 0.000_001)
    }

    @Test func extremelyNarrowWidthKeepsMinimumCellWidth() {
        let size = WorkspaceLayoutPolicy.editorItemSize(
            availableWidth: 1,
            columns: 8,
            leftInset: 8,
            rightInset: 8,
            interitemSpacing: 8
        )
        #expect(size.width == 20)
        #expect(abs(size.height - 20 / 0.72) < 0.000_001)
    }

    @Test func invalidColumnCountIsHandledAsOneColumn() {
        let size = WorkspaceLayoutPolicy.editorItemSize(
            availableWidth: 100,
            columns: 0,
            leftInset: 8,
            rightInset: 8,
            interitemSpacing: 8
        )
        #expect(size.width == 84)
    }
}
