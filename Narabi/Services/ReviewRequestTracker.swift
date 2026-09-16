import Foundation

enum ReviewRequestTracker {
    private static let countKey = "completedExportCount"
    private static let requestedKey = "didRequestReview"
    static func recordSuccessfulExport() -> Bool {
        guard !UserDefaults.standard.bool(forKey: requestedKey) else { return false }
        let count = UserDefaults.standard.integer(forKey: countKey) + 1
        UserDefaults.standard.set(count, forKey: countKey)
        guard count >= 3 else { return false }
        UserDefaults.standard.set(true, forKey: requestedKey)
        return true
    }
}
