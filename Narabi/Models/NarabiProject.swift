import Foundation

nonisolated struct NarabiProject: Identifiable, Codable, Equatable {
    var id = UUID()
    var outputName = ""
    var pages: [ProjectPage] = []
    var tray: [ProjectPage] = []
    var deleted: [ProjectPage] = []
    var updatedAt = Date()
    var isTrayCollapsed = false
    var approximateBytes: Int64 = 0
    var folderID: UUID?
    var browserOrder: Int = 0

    var previewItem: ProjectPage? {
        pages.first ?? tray.first
    }
}

nonisolated extension NarabiProject {
    enum CodingKeys: String, CodingKey {
        case id, outputName, pages, tray, deleted, updatedAt, isTrayCollapsed, approximateBytes, folderID,
            browserOrder
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        outputName = try c.decodeIfPresent(String.self, forKey: .outputName) ?? ""
        pages = try c.decodeIfPresent([ProjectPage].self, forKey: .pages) ?? []
        tray = try c.decodeIfPresent([ProjectPage].self, forKey: .tray) ?? []
        deleted = try c.decodeIfPresent([ProjectPage].self, forKey: .deleted) ?? []
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        isTrayCollapsed = try c.decodeIfPresent(Bool.self, forKey: .isTrayCollapsed) ?? false
        approximateBytes = try c.decodeIfPresent(Int64.self, forKey: .approximateBytes) ?? 0
        folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        browserOrder = try c.decodeIfPresent(Int.self, forKey: .browserOrder) ?? 0
    }
}
