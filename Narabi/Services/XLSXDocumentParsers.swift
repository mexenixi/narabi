import Foundation

nonisolated final class SharedStringParser: NSObject, XMLParserDelegate {
    private var collecting = false
    private var current = ""
    private var strings: [String] = []

    static func parse(_ data: Data) -> [String] {
        let delegate = SharedStringParser()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        parser.parse()
        delegate.flush()
        return delegate.strings
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]
    ) {
        if local(elementName) == "si" { flush() }
        if local(elementName) == "t" { collecting = true }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collecting { current.append(string) }
    }
    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if local(elementName) == "t" { collecting = false }
        if local(elementName) == "si" { flush() }
    }
    private func flush() {
        if !current.isEmpty { strings.append(current) }
        current = ""
    }
    private func local(_ value: String) -> String {
        value.split(separator: ":").last.map(String.init) ?? value
    }
}

nonisolated final class WorksheetParser: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]
    private var type: String?
    private var collectingValue = false
    private var collectingInline = false
    private var value = ""
    private var inline = ""
    private var row: [String] = []
    private var rows: [[String]] = []

    init(sharedStrings: [String]) { self.sharedStrings = sharedStrings }

    func parse(_ data: Data) -> [[String]] {
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = self
        parser.parse()
        flushRow()
        return rows
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]
    ) {
        let name = local(elementName)
        if name == "c" {
            type = attributeDict["t"]
            value = ""
            inline = ""
        }
        if name == "v" { collectingValue = true }
        if name == "t", type == "inlineStr" { collectingInline = true }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collectingValue { value.append(string) }
        if collectingInline { inline.append(string) }
    }
    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = local(elementName)
        if name == "v" { collectingValue = false }
        if name == "t" { collectingInline = false }
        if name == "c" {
            var resolved = inline.isEmpty ? value : inline
            if type == "s", let index = Int(value), sharedStrings.indices.contains(index) {
                resolved = sharedStrings[index]
            }
            if type == "b" { resolved = value == "1" ? "TRUE" : "FALSE" }
            row.append(resolved)
        }
        if name == "row" { flushRow() }
    }
    private func flushRow() {
        if !row.isEmpty { rows.append(row) }
        row = []
    }
    private func local(_ value: String) -> String {
        value.split(separator: ":").last.map(String.init) ?? value
    }
}
