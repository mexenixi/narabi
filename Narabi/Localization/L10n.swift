import Foundation
import SwiftUI

enum L10n {
    static let languageKey = "appLanguage"
    static let supportedLanguages: Set<String> = [
        "ja", "en", "zh-Hans", "zh-Hant", "ko", "es", "fr", "de",
        "pt-BR", "it", "nl", "pl", "tr", "id", "th", "vi", "ar", "he", "hi", "ru", "uk",
    ]

    static var selectedLanguage: String {
        UserDefaults.standard.string(forKey: languageKey) ?? "system"
    }

    static var effectiveLanguage: String {
        normalizedLanguage(
            selectedLanguage == "system"
                ? (Locale.preferredLanguages.first ?? "en")
                : selectedLanguage)
    }

    static var locale: Locale { Locale(identifier: effectiveLanguage) }

    static var layoutDirection: LayoutDirection {
        Locale.Language(identifier: effectiveLanguage).characterDirection == .rightToLeft
            ? .rightToLeft
            : .leftToRight
    }

    static var legalDocumentLanguage: String {
        effectiveLanguage == "ja" ? "ja" : "en"
    }

    static var refreshID: String {
        "\(effectiveLanguage)|\(layoutDirection == .rightToLeft ? "rtl" : "ltr")"
    }

    static func normalizedLanguage(_ raw: String) -> String {
        let canonical = raw.replacingOccurrences(of: "_", with: "-")
        let lower = canonical.lowercased()
        if lower.hasPrefix("zh-hans") || lower.hasPrefix("zh-cn") || lower.hasPrefix("zh-sg") {
            return "zh-Hans"
        }
        if lower.hasPrefix("zh-hant") || lower.hasPrefix("zh-tw") || lower.hasPrefix("zh-hk")
            || lower.hasPrefix("zh-mo")
        {
            return "zh-Hant"
        }
        if lower.hasPrefix("pt") { return "pt-BR" }
        let base = String(lower.split(separator: "-").first ?? "en")
        return supportedLanguages.contains(base) ? base : "en"
    }

    private static var localizedBundle: Bundle {
        guard let path = Bundle.main.path(forResource: effectiveLanguage, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }

    static func text(_ key: String, _ fallback: String) -> String {
        localizedBundle.localizedString(forKey: key, value: fallback, table: nil)
    }

    static func formatString(_ key: String, _ value: CVarArg) -> String {
        String(format: text(key, "%@"), locale: locale, arguments: [value])
    }

    static func format(_ key: String, _ value: CVarArg) -> String {
        String(format: text(key, "%lld"), locale: locale, arguments: [value])
    }
}
