import CoreGraphics

nonisolated enum WorkspaceLayoutPolicy {
    static let phoneColumnCount = 3
    static let minimumCellWidth: CGFloat = 20
    static let cellAspectRatio: CGFloat = 0.72

    static func editorColumnCount(isPad: Bool, availableWidth: CGFloat) -> Int {
        guard isPad else { return phoneColumnCount }
        switch availableWidth {
        case ..<600:
            return 4
        case ..<850:
            return 5
        case ..<1_100:
            return 6
        case ..<1_350:
            return 7
        default:
            return 8
        }
    }

    static func editorItemSize(
        availableWidth: CGFloat,
        columns: Int,
        leftInset: CGFloat,
        rightInset: CGFloat,
        interitemSpacing: CGFloat
    ) -> CGSize {
        let safeColumns = max(columns, 1)
        let horizontalInsets = leftInset + rightInset
        let totalSpacing = CGFloat(max(safeColumns - 1, 0)) * interitemSpacing
        let usableWidth = max(availableWidth - horizontalInsets - totalSpacing, 1)
        let width = max(floor(usableWidth / CGFloat(safeColumns)), minimumCellWidth)
        return CGSize(width: width, height: width / cellAspectRatio)
    }
}
