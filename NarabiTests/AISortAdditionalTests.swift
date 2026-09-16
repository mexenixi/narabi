import Foundation
import Testing
@testable import Narabi

@Suite("Additional AI sort validation")
struct AISortAdditionalTests {
    private let request = ActiveAISortRequest(
        projectID: UUID(),
        code: "ABC123",
        pages: [
            AIPageReference(id: "P001", pageID: UUID(), fixedEditorIndex: 0),
            AIPageReference(id: "P002", pageID: UUID(), fixedEditorIndex: 1),
            AIPageReference(id: "P003", pageID: UUID(), fixedEditorIndex: 2),
        ],
        prompt: "Sort",
        originalSelection: [])

    @Test func acceptsWindowsLineEndings() throws {
        let result = AISortPackageService.parse(
            "intro\r\nSESSION:ABC123|ORDER:P002,P001,P003|REASON:ok\r\noutro", request: request)
        let value = try success(result)
        #expect(value.0 == ["P002", "P001", "P003"])
    }

    @Test func acceptsEmptyReason() throws {
        let value = try success(AISortPackageService.parse(
            "SESSION:ABC123|ORDER:P001,P002,P003|REASON:", request: request))
        #expect(value.1.isEmpty)
    }

    @Test func rejectsExtraIdentifier() {
        expectCode("SESSION:ABC123|ORDER:P001,P002,P003,P004|REASON:x", 4)
    }

    @Test func rejectsEmptyOrder() {
        expectCode("SESSION:ABC123|ORDER:|REASON:x", 4)
    }

    @Test func rejectsIdentifierCaseChanges() {
        expectCode("SESSION:ABC123|ORDER:p001,P002,P003|REASON:x", 4)
    }

    @Test func usesTheFirstCompleteResultLine() throws {
        let text = """
        SESSION:ABC123|ORDER:P003,P002,P001|REASON:first
        SESSION:ABC123|ORDER:P001,P002,P003|REASON:second
        """
        let value = try success(AISortPackageService.parse(text, request: request))
        #expect(value.0 == ["P003", "P002", "P001"])
        #expect(value.1 == "first")
    }

    private func expectCode(_ text: String, _ code: Int) {
        switch AISortPackageService.parse(text, request: request) {
        case .success: Issue.record("Expected failure")
        case .failure(let error): #expect((error as NSError).code == code)
        }
    }

    private func success(_ result: Result<([String], String), Error>) throws -> ([String], String) {
        switch result {
        case .success(let value): value
        case .failure(let error): throw error
        }
    }
}
