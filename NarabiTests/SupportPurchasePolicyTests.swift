import Testing

@testable import Narabi

@MainActor
struct SupportPurchasePolicyTests {
    @Test func catalogContainsThreeUniqueLowercaseIdentifiers() {
        #expect(SupportPurchaseCatalog.productIDs.count == 3)
        #expect(Set(SupportPurchaseCatalog.productIDs).count == 3)
        #expect(SupportPurchaseCatalog.productIDs.allSatisfy { $0 == $0.lowercased() })
    }

    @Test func catalogUsesTheExpectedIdentifiers() {
        #expect(
            SupportPurchaseCatalog.productIDs == [
                "com.mexenixi.narabi.support.small",
                "com.mexenixi.narabi.support.medium",
                "com.mexenixi.narabi.support.large",
            ])
    }

    @Test func everyProductHasANameKey() {
        #expect(SupportPurchaseCatalog.items.allSatisfy { !$0.nameKey.isEmpty })
    }

    @Test func unknownProductsAreRejected() {
        #expect(!SupportPurchaseCatalog.contains("com.example.unknown"))
    }

    @Test func idlePhaseAllowsKnownPurchase() {
        #expect(SupportPurchasePhase.idle.canStartPurchase(productID: SupportPurchaseCatalog.productIDs[0]))
    }

    @Test func busyPhasesBlockAdditionalPurchases() {
        #expect(
            !SupportPurchasePhase.loading.canStartPurchase(productID: SupportPurchaseCatalog.productIDs[0]))
        #expect(
            !SupportPurchasePhase.purchasing(productID: SupportPurchaseCatalog.productIDs[0])
                .canStartPurchase(productID: SupportPurchaseCatalog.productIDs[1]))
    }
}
