import Foundation
import Testing
@testable import Narabi

@Suite("Structured document import", .serialized)
struct StructuredDocumentImportTests {
    @Test func emptyLosslessBodyProducesNoPages() {
        #expect(LosslessDocumentRenderer.render(title: "Empty", body: NSAttributedString()).isEmpty)
    }

    @Test func validJSONRendersAtLeastOnePage() throws {
        let file = try temporaryFile(name: "sample.json", contents: "{\"name\":\"Narabi\",\"pages\":[1,2,3]}")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(try StructuredJSONImporter.render(url: file, title: "JSON").isEmpty == false)
    }

    @Test func invalidJSONThrows() throws {
        let file = try temporaryFile(name: "broken.json", contents: "{broken")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(throws: (any Error).self) {
            _ = try StructuredJSONImporter.render(url: file, title: "JSON")
        }
    }

    @Test func validXMLRendersAtLeastOnePage() throws {
        let file = try temporaryFile(name: "sample.xml", contents: "<root><item>First</item><item>Second</item></root>")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(try StructuredXMLImporter.render(url: file, title: "XML").isEmpty == false)
    }

    @Test func validPropertyListRendersAtLeastOnePage() throws {
        let file = try temporaryFile(name: "sample.plist", contents: """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>Name</key><string>Narabi</string></dict></plist>
        """)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(try StructuredPlistImporter.render(url: file, title: "Plist").isEmpty == false)
    }

    @Test func invalidPropertyListThrows() throws {
        let file = try temporaryFile(name: "broken.plist", contents: "not a plist")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(throws: (any Error).self) {
            _ = try StructuredPlistImporter.render(url: file, title: "Plist")
        }
    }

    @Test func timedTextRendersAtLeastOnePage() throws {
        let file = try temporaryFile(name: "sample.srt", contents: "1\n00:00:00,000 --> 00:00:02,000\nHello\n")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(try TimedTextDocumentImporter.render(url: file, title: "SRT").isEmpty == false)
    }

    @Test func calendarRendersAtLeastOnePage() throws {
        let file = try temporaryFile(name: "sample.ics", contents: "BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nSUMMARY:Test\nEND:VEVENT\nEND:VCALENDAR\n")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(try CalendarDocumentImporter.render(url: file, title: "Calendar").isEmpty == false)
    }

    private func temporaryFile(name: String, contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "NarabiStructuredTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }
}
