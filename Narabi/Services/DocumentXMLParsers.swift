import Foundation

nonisolated final class SimpleTextXMLParser: NSObject, XMLParserDelegate {
    private let paragraphNames: Set<String>
    private let textNames: Set<String>
    private var collecting = false
    private var current = ""
    private var values: [String] = []

    private init(paragraphNames: Set<String>, textNames: Set<String>) {
        self.paragraphNames = paragraphNames
        self.textNames = textNames
    }

    static func parse(_ data: Data, paragraphNames: Set<String>, textNames: Set<String>) -> [String] {
        let delegate = SimpleTextXMLParser(paragraphNames: paragraphNames, textNames: textNames)
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        parser.parse()
        delegate.flush()
        return delegate.values
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]
    ) {
        let name = local(elementName)
        if paragraphNames.contains(name) { flush() }
        if textNames.contains(name) { collecting = true }
        if name == "tab" { current.append("\t") }
        if name == "br" { current.append("\n") }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collecting { current.append(string) }
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = local(elementName)
        if textNames.contains(name) { collecting = false }
        if paragraphNames.contains(name) { flush() }
    }

    private func flush() {
        let value = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty { values.append(value) }
        current = ""
    }

    private func local(_ value: String) -> String {
        value.split(separator: ":").last.map(String.init) ?? value
    }
}
