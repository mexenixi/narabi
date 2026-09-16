import Foundation

nonisolated struct ProjectFolder: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var browserOrder: Int
}
