import Foundation

nonisolated final class WordXMLParser: NSObject, XMLParserDelegate {
    private var collecting = false
    private var currentCell = ""
    private var row: [String] = []
    private var block: [String] = []
    private var groups: [[String]] = []
    private var inTableCell = false

    func parse(_ data: Data) -> [[String]] {
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = self
        parser.parse()
        flushCell()
        flushRow()
        flushGroup()
        return groups
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]
    ) {
        let name = local(elementName)
        if name == "tc" {
            inTableCell = true
            currentCell = ""
        }
        if name == "t" { collecting = true }
        if name == "tab" { currentCell.append("\t") }
        if name == "br" {
            let type = attributeDict.first { local($0.key) == "type" }?.value
            if type == "page" {
                flushCell()
                flushRow()
                flushGroup()
            } else {
                currentCell.append("\n")
            }
        }
        if name == "lastRenderedPageBreak" {
            flushCell()
            flushRow()
            flushGroup()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collecting { currentCell.append(string) }
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = local(elementName)
        if name == "t" { collecting = false }
        if name == "tc" {
            flushCell()
            inTableCell = false
        }
        if name == "tr" { flushRow() }
        if name == "p", !inTableCell { flushCell() }
        if name == "sectPr" { flushGroup() }
    }

    private func flushCell() {
        let value = currentCell.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            if inTableCell { row.append(value) } else { block.append(value) }
        }
        currentCell = ""
    }

    private func flushRow() {
        if !row.isEmpty { block.append(row.joined(separator: "  |  ")) }
        row = []
    }

    private func flushGroup() {
        if !block.isEmpty { groups.append(block) }
        block = []
    }

    private func local(_ value: String) -> String {
        value.split(separator: ":").last.map(String.init) ?? value
    }
}
