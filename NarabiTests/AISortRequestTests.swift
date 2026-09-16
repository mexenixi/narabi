import Foundation
import Testing
@testable import Narabi

@Suite("AI sort request creation")
struct AISortRequestTests {
    @Test func rejectsAnEmptyPageList() {
        #expect(AISortPackageService.request(projectID: UUID(), pages: [], prompt: "Sort") == nil)
    }

    @Test func assignsStableSequentialReferencesAndIndexes() throws {
        let first = page(1)
        let second = page(2)
        let request = try #require(AISortPackageService.request(
            projectID: UUID(), pages: [(index: 7, page: first), (index: 2, page: second)], prompt: "Date"))
        #expect(request.pages.map(\.id) == ["P001", "P002"])
        #expect(request.pages.map(\.pageID) == [first.id, second.id])
        #expect(request.pages.map(\.fixedEditorIndex) == [7, 2])
        #expect(request.originalSelection == [first.id, second.id])
        #expect(request.prompt == "Date")
    }

    @Test func createsSixUppercaseSessionCharacters() throws {
        let request = try #require(AISortPackageService.request(
            projectID: UUID(), pages: [(index: 0, page: page(1))], prompt: "Sort"))
        #expect(request.code.count == 6)
        #expect(request.code == request.code.uppercased())
        #expect(request.code.allSatisfy { $0.isLetter || $0.isNumber })
    }

    @Test func supportsOneHundredPageReferencesWithoutDuplicates() throws {
        let pages = (0..<100).map { (index: $0, page: page(UInt8($0 % 255))) }
        let request = try #require(AISortPackageService.request(projectID: UUID(), pages: pages, prompt: "Sort"))
        #expect(request.pages.count == 100)
        #expect(request.pages.first?.id == "P001")
        #expect(request.pages.last?.id == "P100")
        #expect(Set(request.pages.map(\.id)).count == 100)
    }

    private func page(_ byte: UInt8) -> ProjectPage {
        ProjectPage(originalData: Data([byte]), renderedData: Data([byte]))
    }
}
