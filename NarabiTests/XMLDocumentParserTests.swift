import Foundation
import Testing
@testable import Narabi

@Suite("XML document parsers")
struct XMLDocumentParserTests {
    @Test func simpleTextParserCollectsParagraphText() {
        let xml = Data("<root><p><t>Hello </t><t>World</t></p><p><t>Next</t></p></root>".utf8)
        let values = SimpleTextXMLParser.parse(xml, paragraphNames: ["p"], textNames: ["t"])
        #expect(values == ["Hello World", "Next"])
    }

    @Test func simpleTextParserHandlesNamespacedElements() {
        let xml = Data("<w:root xmlns:w=\"urn:test\"><w:p><w:t>Text</w:t></w:p></w:root>".utf8)
        let values = SimpleTextXMLParser.parse(xml, paragraphNames: ["p"], textNames: ["t"])
        #expect(values == ["Text"])
    }

    @Test func sharedStringsCombineRichTextRuns() {
        let xml = Data("<sst><si><t>Hello </t><r><t>World</t></r></si><si><t>Next</t></si></sst>".utf8)
        #expect(SharedStringParser.parse(xml) == ["Hello World", "Next"])
    }

    @Test func worksheetResolvesSharedInlineBooleanAndNumericCells() {
        let xml = Data("""
        <worksheet><sheetData><row>
        <c t="s"><v>1</v></c>
        <c t="inlineStr"><is><t>Inline</t></is></c>
        <c t="b"><v>1</v></c>
        <c><v>42</v></c>
        </row></sheetData></worksheet>
        """.utf8)
        let rows = WorksheetParser(sharedStrings: ["Zero", "Shared"]).parse(xml)
        #expect(rows == [["Shared", "Inline", "TRUE", "42"]])
    }

    @Test func worksheetConvertsFalseBoolean() {
        let xml = Data("<worksheet><sheetData><row><c t=\"b\"><v>0</v></c></row></sheetData></worksheet>".utf8)
        #expect(WorksheetParser(sharedStrings: []).parse(xml) == [["FALSE"]])
    }
}
