import Foundation
import Testing
@testable import Narabi

@Suite("AI sort result validation")
struct AISortResultValidationTests {
    private let request = ActiveAISortRequest(
        projectID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        code: "ABC123",
        pages: [
            AIPageReference(
                id: "P001",
                pageID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                fixedEditorIndex: 0),
            AIPageReference(
                id: "P002",
                pageID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
                fixedEditorIndex: 1),
            AIPageReference(
                id: "P003",
                pageID: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
                fixedEditorIndex: 2),
        ],
        prompt: "Arrange the pages.",
        originalSelection: [])

    @Test("Accepts a complete reordered result")
    func acceptsCompleteReorderedResult() throws {
        let value = try success(
            AISortPackageService.parse(
                "SESSION:ABC123|ORDER:P003,P001,P002|REASON:chronological",
                request: request))
        #expect(value.0 == ["P003", "P001", "P002"])
        #expect(value.1 == "chronological")
    }

    @Test("Accepts a result line inside surrounding text")
    func acceptsResultInsideSurroundingText() throws {
        let value = try success(
            AISortPackageService.parse(
                "Result follows:\n```text\nSESSION:ABC123|ORDER:P002,P003,P001|REASON:grouped\n```",
                request: request))
        #expect(value.0 == ["P002", "P003", "P001"])
        #expect(value.1 == "grouped")
    }

    @Test("Rejects ordinary text")
    func rejectsOrdinaryText() {
        expectFailureCode(
            AISortPackageService.parse("あ", request: request),
            expectedCode: 1)
    }

    @Test("Rejects a different session")
    func rejectsDifferentSession() {
        expectFailureCode(
            AISortPackageService.parse(
                "SESSION:ZZZ999|ORDER:P001,P002,P003|REASON:test",
                request: request),
            expectedCode: 3)
    }

    @Test("Rejects a missing page identifier")
    func rejectsMissingPageIdentifier() {
        expectFailureCode(
            AISortPackageService.parse(
                "SESSION:ABC123|ORDER:P001,P002|REASON:test",
                request: request),
            expectedCode: 4)
    }

    @Test("Rejects a duplicate page identifier")
    func rejectsDuplicatePageIdentifier() {
        expectFailureCode(
            AISortPackageService.parse(
                "SESSION:ABC123|ORDER:P001,P001,P003|REASON:test",
                request: request),
            expectedCode: 4)
    }

    private func success(
        _ result: Result<([String], String), Error>
    ) throws -> ([String], String) {
        switch result {
        case .success(let value): value
        case .failure(let error): throw error
        }
    }

    private func expectFailureCode(
        _ result: Result<([String], String), Error>,
        expectedCode: Int
    ) {
        switch result {
        case .success:
            Issue.record("Expected parsing to fail")
        case .failure(let error):
            #expect((error as NSError).domain == "AISort")
            #expect((error as NSError).code == expectedCode)
        }
    }
}

@Suite("Editor history policy")
struct EditorHistoryPolicyTests {
    @Test("Keeps a stack at the maximum size")
    func keepsMaximumSize() {
        var stack = (0..<EditorHistoryPolicy.maximumEntryCount).map { project(order: $0) }
        EditorHistoryPolicy.trim(&stack)
        #expect(stack.count == EditorHistoryPolicy.maximumEntryCount)
        #expect(stack.first?.browserOrder == 0)
    }

    @Test("Drops only the oldest history entries")
    func dropsOldestEntries() {
        var stack = (0..<(EditorHistoryPolicy.maximumEntryCount + 5)).map { project(order: $0) }
        EditorHistoryPolicy.trim(&stack)
        #expect(stack.count == EditorHistoryPolicy.maximumEntryCount)
        #expect(stack.first?.browserOrder == 5)
        #expect(stack.last?.browserOrder == EditorHistoryPolicy.maximumEntryCount + 4)
    }

    @Test("Does not change a short history stack")
    func preservesShortStack() {
        var stack = (0..<3).map { project(order: $0) }
        let original = stack
        EditorHistoryPolicy.trim(&stack)
        #expect(stack == original)
    }

    private func project(order: Int) -> NarabiProject {
        var value = NarabiProject()
        value.browserOrder = order
        return value
    }
}

@Suite("Project persistence model")
struct ProjectPersistenceTests {
    @Test("Round-trips page areas and project metadata")
    func roundTripsProjectMetadata() throws {
        var project = NarabiProject()
        project.outputName = "Test Project"
        project.isTrayCollapsed = true
        project.approximateBytes = 42_000
        project.browserOrder = 7
        project.folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000777")

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(NarabiProject.self, from: data)
        #expect(decoded == project)
        #expect(decoded.pages.isEmpty)
        #expect(decoded.tray.isEmpty)
        #expect(decoded.deleted.isEmpty)
    }

    @Test("Decodes missing optional project fields with safe defaults")
    func decodesLegacyDefaults() throws {
        let decoded = try JSONDecoder().decode(NarabiProject.self, from: Data("{}".utf8))
        #expect(decoded.outputName.isEmpty)
        #expect(decoded.pages.isEmpty)
        #expect(decoded.tray.isEmpty)
        #expect(decoded.deleted.isEmpty)
        #expect(decoded.isTrayCollapsed == false)
        #expect(decoded.approximateBytes == 0)
        #expect(decoded.folderID == nil)
        #expect(decoded.browserOrder == 0)
    }
}

@Suite("Export configuration")
struct ExportConfigurationTests {
    @Test("Uses stable default export settings")
    func defaultSettings() {
        let configuration = ExportConfiguration()
        #expect(configuration.preset == .pdf)
        #expect(configuration.longEdge == .px2048)
        #expect(configuration.jpegQuality == 0.88)
    }

    @Test("Includes every supported export destination")
    func exportPresets() {
        #expect(Set(ExportPreset.allCases) == Set([.pdf, .jpeg, .png, .transparentPNG, .photos]))
    }

    @Test("Includes every export color policy")
    func colorPolicies() {
        #expect(
            Set(ExportColorPolicy.allCases)
                == Set([.perPage, .allColor, .allGrayscale, .allMonochrome]))
    }

    @Test("Preserves export settings through Codable")
    func codableRoundTrip() throws {
        let original = ExportConfiguration(preset: .transparentPNG, longEdge: .px4096, jpegQuality: 0.73)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExportConfiguration.self, from: data)
        #expect(decoded == original)
    }
}

@Suite("Paper sizes and units")
struct PaperModelTests {
    @Test("Converts centimeters to and from millimeters")
    func centimeters() {
        #expect(PaperUnit.centimeter.millimeters(from: 21) == 210)
        #expect(PaperUnit.centimeter.displayValue(fromMM: 297) == 29.7)
    }

    @Test("Converts inches to and from millimeters")
    func inches() {
        #expect(abs(PaperUnit.inch.millimeters(from: 1) - 25.4) < 0.000_001)
        #expect(abs(PaperUnit.inch.displayValue(fromMM: 25.4) - 1) < 0.000_001)
    }

    @Test("Returns A4 portrait and landscape dimensions")
    func a4Dimensions() {
        let portrait = PaperPreset.a4.sizeMM(
            orientation: .portrait, customWidthMM: 1, customHeightMM: 1)
        let landscape = PaperPreset.a4.sizeMM(
            orientation: .landscape, customWidthMM: 1, customHeightMM: 1)
        #expect(portrait.width == 210)
        #expect(portrait.height == 297)
        #expect(landscape.width == 297)
        #expect(landscape.height == 210)
    }

    @Test("Uses custom dimensions without swapping them")
    func customDimensions() {
        let custom = PaperPreset.custom.sizeMM(
            orientation: .landscape, customWidthMM: 123, customHeightMM: 456)
        #expect(custom.width == 123)
        #expect(custom.height == 456)
    }
}
