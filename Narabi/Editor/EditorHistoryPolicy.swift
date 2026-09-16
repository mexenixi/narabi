import Foundation

nonisolated enum EditorHistoryPolicy {
    static let maximumEntryCount = 30
    static func trim(_ stack: inout [NarabiProject]) {
        guard stack.count > maximumEntryCount else { return }
        stack.removeFirst(stack.count - maximumEntryCount)
    }
}
