import SwiftUI
import Testing
@testable import Narabi

@Suite("Localization contracts", .serialized)
struct LocalizationContractTests {
    @Test func normalizesChineseRegions() {
        #expect(L10n.normalizedLanguage("zh_CN") == "zh-Hans")
        #expect(L10n.normalizedLanguage("zh-SG") == "zh-Hans")
        #expect(L10n.normalizedLanguage("zh_Hant") == "zh-Hant")
        #expect(L10n.normalizedLanguage("zh-TW") == "zh-Hant")
        #expect(L10n.normalizedLanguage("zh-HK") == "zh-Hant")
        #expect(L10n.normalizedLanguage("zh-MO") == "zh-Hant")
    }

    @Test func normalizesPortugueseToBrazilianPortuguese() {
        #expect(L10n.normalizedLanguage("pt") == "pt-BR")
        #expect(L10n.normalizedLanguage("pt_PT") == "pt-BR")
        #expect(L10n.normalizedLanguage("pt-BR") == "pt-BR")
    }

    @Test func keepsSupportedBaseLanguages() {
        #expect(L10n.normalizedLanguage("ja-JP") == "ja")
        #expect(L10n.normalizedLanguage("en_US") == "en")
        #expect(L10n.normalizedLanguage("ar-SA") == "ar")
        #expect(L10n.normalizedLanguage("he-IL") == "he")
    }

    @Test func unknownLanguageFallsBackToEnglish() {
        #expect(L10n.normalizedLanguage("xx-YY") == "en")
        #expect(L10n.normalizedLanguage("") == "en")
    }
}
