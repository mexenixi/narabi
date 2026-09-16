import Foundation

enum SupportPurchaseCatalog {
    struct Item: Equatable, Sendable {
        let id: String
        let nameKey: String
    }

    static let items = [
        Item(id: "com.mexenixi.narabi.support.small", nameKey: "support.product.small"),
        Item(id: "com.mexenixi.narabi.support.medium", nameKey: "support.product.medium"),
        Item(id: "com.mexenixi.narabi.support.large", nameKey: "support.product.large"),
    ]

    static let productIDs = items.map(\.id)
    static let nameKeysByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.nameKey) })

    static func contains(_ productID: String) -> Bool {
        nameKeysByID[productID] != nil
    }
}

enum SupportPurchasePhase: Equatable {
    case idle
    case loading
    case purchasing(productID: String)
    case pending
    case succeeded
    case unverified
    case failed(message: String)

    var isBusy: Bool {
        switch self {
        case .loading, .purchasing:
            true
        default:
            false
        }
    }

    func canStartPurchase(productID: String) -> Bool {
        SupportPurchaseCatalog.contains(productID) && !isBusy
    }
}
