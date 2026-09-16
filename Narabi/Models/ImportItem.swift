import Foundation

struct ImportItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case image
        case pdf
    }

    var id = UUID()
    var kind: Kind
    var data: Data
    var displayName: String
}
