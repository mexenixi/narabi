import SwiftUI
import Testing
@testable import Narabi

@Suite("Stable app contracts")
struct AppContractTests {
    @Test func supportsDeclaredOfficeAndTextExtensions() {
        let required: Set<String> = [
            "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "text", "md", "markdown",
            "csv", "tsv", "log", "json", "xml", "html", "htm", "yaml", "yml", "ics",
            "pages", "numbers", "key",
        ]
        #expect(OfficeImportService.extensions == required)
    }

    @Test func exportLongEdgesRemainStable() {
        #expect(
            ExportLongEdge.allCases.map(\.rawValue) == [
                -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1,
                0, 1200, 1600, 1920, 2048, 2560, 3072, 3840, 4096, 7680,
            ])
    }

    @Test func exportPresetKeysAndSymbolsAreUnique() {
        #expect(Set(ExportPreset.allCases.map(\.titleKey)).count == ExportPreset.allCases.count)
        #expect(Set(ExportPreset.allCases.map(\.symbol)).count == ExportPreset.allCases.count)
    }

    @Test func appearanceMapsToExpectedColorSchemes() {
        #expect(AppAppearance.system.colorScheme == nil)
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
    }

    @Test func AIReadOptionIdentifiersMatchRawValues() {
        #expect(AIReadMode.allCases.allSatisfy { $0.id == $0.rawValue })
        #expect(AIPDFQuality.allCases.allSatisfy { $0.id == $0.rawValue })
        #expect(AIOCRPreparation.allCases.allSatisfy { $0.id == $0.rawValue })
    }

    @Test func publicLinksUseHTTPSAndExpectedHosts() {
        let links = [
            AppPublicLinks.website, AppPublicLinks.product, AppPublicLinks.support,
            AppPublicLinks.privacy, AppPublicLinks.terms, AppPublicLinks.commercialTransactions,
            AppPublicLinks.github, AppPublicLinks.youtube, AppPublicLinks.instagram,
            AppPublicLinks.x, AppPublicLinks.tiktok,
        ]
        #expect(links.allSatisfy { $0.scheme == "https" })
        #expect(AppPublicLinks.product.host == "by.mexenixi.workers.dev")
        #expect(AppPublicLinks.github.host == "github.com")
        #expect(AppPublicLinks.github.path == "/mexenixi/narabi")
    }
}
