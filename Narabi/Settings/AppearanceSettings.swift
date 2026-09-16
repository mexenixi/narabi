import Combine
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class AppearanceSettings: ObservableObject {
    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance") }
    }
    init() {
        appearance =
            AppAppearance(rawValue: UserDefaults.standard.string(forKey: "appAppearance") ?? "system")
            ?? .system
    }
}
