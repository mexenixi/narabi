import Foundation

nonisolated enum TemporaryFileMaintenance {
    private static let imageExportPrefix = "NarabiImageExport-"
    private static let aiDirectoryName = "NarabiAIFiles"

    static func removeOldOwnedTemporaryItems(olderThan age: TimeInterval = 24 * 60 * 60) {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
        let cutoff = Date().addingTimeInterval(-age)

        guard
            let children = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else { return }

        for child in children {
            let name = child.lastPathComponent
            let isOwnedDirectory = name.hasPrefix(imageExportPrefix) || name == aiDirectoryName
            guard isOwnedDirectory else { continue }

            let values = try? child.resourceValues(
                forKeys: [.contentModificationDateKey, .isDirectoryKey]
            )
            guard
                values?.isDirectory == true,
                let modified = values?.contentModificationDate,
                modified < cutoff
            else { continue }

            try? fileManager.removeItem(at: child)
        }
    }
}
