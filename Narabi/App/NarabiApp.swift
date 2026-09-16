import SwiftUI

@main
struct NarabiApp: App {
    @StateObject private var store = ProjectStore()
    @StateObject private var appearance = AppearanceSettings()
    @StateObject private var supportTransactions = SupportTransactionObserver()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
                .environmentObject(appearance)
                .environmentObject(supportTransactions)
                .preferredColorScheme(appearance.appearance.colorScheme)
        }
    }
}
