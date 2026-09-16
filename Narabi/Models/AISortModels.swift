import Foundation

nonisolated struct AIPageReference: Codable, Equatable, Identifiable {
    let id: String
    let pageID: UUID
    let fixedEditorIndex: Int
}

nonisolated struct ActiveAISortRequest: Codable, Equatable {
    let projectID: UUID
    let code: String
    let pages: [AIPageReference]
    let prompt: String
    let originalSelection: [UUID]
}
