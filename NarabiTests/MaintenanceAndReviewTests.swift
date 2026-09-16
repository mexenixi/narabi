import Foundation
import Testing
@testable import Narabi

@Suite("Temporary file maintenance", .serialized)
struct TemporaryFileMaintenanceTests {
    @Test func removesOnlyOldOwnedExportDirectories() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory
        let suffix = UUID().uuidString
        let oldOwned = root.appendingPathComponent("NarabiImageExport-Old-\(suffix)", isDirectory: true)
        let recentOwned = root.appendingPathComponent("NarabiImageExport-New-\(suffix)", isDirectory: true)
        let unrelated = root.appendingPathComponent("Unrelated-\(suffix)", isDirectory: true)
        for url in [oldOwned, recentOwned, unrelated] {
            try manager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        defer { for url in [oldOwned, recentOwned, unrelated] { try? manager.removeItem(at: url) } }
        let oldDate = Date().addingTimeInterval(-7200)
        try manager.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldOwned.path)
        try manager.setAttributes([.modificationDate: oldDate], ofItemAtPath: unrelated.path)

        TemporaryFileMaintenance.removeOldOwnedTemporaryItems(olderThan: 3600)

        #expect(manager.fileExists(atPath: oldOwned.path) == false)
        #expect(manager.fileExists(atPath: recentOwned.path))
        #expect(manager.fileExists(atPath: unrelated.path))
    }
}

@Suite("Review request tracker", .serialized)
struct ReviewRequestTrackerTests {
    @Test func requestsOnlyAfterTheThirdSuccessfulExport() {
        let defaults = UserDefaults.standard
        let countKey = "completedExportCount"
        let requestedKey = "didRequestReview"
        let oldCount = defaults.object(forKey: countKey)
        let oldRequested = defaults.object(forKey: requestedKey)
        defer {
            if let oldCount { defaults.set(oldCount, forKey: countKey) } else { defaults.removeObject(forKey: countKey) }
            if let oldRequested { defaults.set(oldRequested, forKey: requestedKey) } else { defaults.removeObject(forKey: requestedKey) }
        }
        defaults.removeObject(forKey: countKey)
        defaults.removeObject(forKey: requestedKey)
        #expect(ReviewRequestTracker.recordSuccessfulExport() == false)
        #expect(ReviewRequestTracker.recordSuccessfulExport() == false)
        #expect(ReviewRequestTracker.recordSuccessfulExport() == true)
        #expect(ReviewRequestTracker.recordSuccessfulExport() == false)
        #expect(defaults.integer(forKey: countKey) == 3)
        #expect(defaults.bool(forKey: requestedKey))
    }
}
