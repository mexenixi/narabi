import Testing
@testable import Narabi

@Suite("Export utility contracts")
struct ExportUtilityContractTests {
    @Test func trimsOuterWhitespace() {
        #expect(ExportService.safeFileBaseName("  Report  ") == "Report")
    }

    @Test func replacesPathAndControlSeparators() {
        #expect(ExportService.safeFileBaseName("A/B:C\\D") == "A_B_C_D")
        #expect(ExportService.safeFileBaseName("A\nB") == "A_B")
    }

    @Test func preservesOrdinaryUnicodeAndPunctuation() {
        #expect(ExportService.safeFileBaseName("並び替えでポン 1.0") == "並び替えでポン 1.0")
        #expect(ExportService.safeFileBaseName("report-final_01") == "report-final_01")
    }

    @Test func emptyOrWhitespaceOnlyNameStaysEmpty() {
        #expect(ExportService.safeFileBaseName("") == "")
        #expect(ExportService.safeFileBaseName("   \n  ") == "")
    }
}
