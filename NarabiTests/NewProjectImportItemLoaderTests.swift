import PDFKit
import Testing
import UIKit

@testable import Narabi

@MainActor
struct NewProjectImportItemLoaderTests {
    @Test func loadsPDFWithoutChangingItsDataOrName() async throws {
        let url = try temporaryURL(name: "sample.pdf")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let data = try #require(makePDFData())
        try data.write(to: url)

        let items = try await NewProjectImportItemLoader.load(from: url)

        #expect(items.count == 1)
        #expect(items[0].kind == .pdf)
        #expect(items[0].data == data)
        #expect(items[0].displayName == "sample.pdf")
    }

    @Test func loadsImageWithoutChangingItsDataOrName() async throws {
        let url = try temporaryURL(name: "photo.PNG")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let data = try #require(solidImage().pngData())
        try data.write(to: url)

        let items = try await NewProjectImportItemLoader.load(from: url)

        #expect(items.count == 1)
        #expect(items[0].kind == .image)
        #expect(items[0].data == data)
        #expect(items[0].displayName == "photo.PNG")
    }

    @Test func pageizesJSONAndNumbersGeneratedPagesInOrder() async throws {
        let url = try temporaryURL(name: "records.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try Data(#"[{"name":"first"},{"name":"second"}]"#.utf8).write(to: url)

        let items = try await NewProjectImportItemLoader.load(from: url)

        #expect(!items.isEmpty)
        #expect(items.allSatisfy { $0.kind == .image })
        #expect(
            items.enumerated().allSatisfy { index, item in
                item.displayName == "records \(index + 1)"
            })
        #expect(items.allSatisfy { UIImage(data: $0.data) != nil })
    }

    @Test func invalidStructuredDocumentProducesNoItems() async throws {
        let url = try temporaryURL(name: "broken.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try Data("not-json".utf8).write(to: url)

        #expect(try await NewProjectImportItemLoader.load(from: url).isEmpty)
    }

    @Test func unsupportedDataProducesNoItems() async throws {
        let url = try temporaryURL(name: "unknown.bin")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: url)

        #expect(try await NewProjectImportItemLoader.load(from: url).isEmpty)
    }

    @Test func missingFileProducesNoItems() async throws {
        let url = try temporaryURL(name: "missing.pdf")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(try await NewProjectImportItemLoader.load(from: url).isEmpty)
    }

    private func temporaryURL(name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }

    private func solidImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 24, height: 16)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 16))
        }
    }

    private func makePDFData() -> Data? {
        let document = PDFDocument()
        guard let page = PDFPage(image: solidImage()) else { return nil }
        document.insert(page, at: 0)
        return document.dataRepresentation()
    }
}
