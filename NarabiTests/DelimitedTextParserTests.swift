import Testing
@testable import Narabi

@Suite("Delimited text parsing")
struct DelimitedTextParserTests {
    @Test func parsesCommaSeparatedRows() {
        #expect(DelimitedTextParser.parse("a,b\nc,d", delimiter: ",") == [["a", "b"], ["c", "d"]])
    }

    @Test func parsesTabs() {
        #expect(DelimitedTextParser.parse("a\tb\n1\t2", delimiter: "\t") == [["a", "b"], ["1", "2"]])
    }

    @Test func preservesDelimiterInsideQuotes() {
        #expect(DelimitedTextParser.parse("\"a,b\",c", delimiter: ",") == [["a,b", "c"]])
    }

    @Test func preservesNewlineInsideQuotes() {
        #expect(DelimitedTextParser.parse("\"a\nb\",c", delimiter: ",") == [["a\nb", "c"]])
    }

    @Test func unescapesDoubleQuotes() {
        #expect(DelimitedTextParser.parse("\"a\"\"b\"", delimiter: ",") == [["a\"b"]])
    }

    @Test func handlesWindowsLineEndings() {
        #expect(DelimitedTextParser.parse("a,b\r\nc,d", delimiter: ",") == [["a", "b"], ["c", "d"]])
    }

    @Test func preservesEmptyFields() {
        #expect(DelimitedTextParser.parse("a,,c\n,", delimiter: ",") == [["a", "", "c"], ["", ""]])
    }

    @Test func emptyInputProducesNoRows() {
        #expect(DelimitedTextParser.parse("", delimiter: ",").isEmpty)
    }
}
