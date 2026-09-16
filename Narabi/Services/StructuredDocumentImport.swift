import CoreText
import Foundation
import UIKit

/// Renders a complete attributed string by advancing through the exact Core Text visible range.
/// No source character is discarded at a page boundary.
nonisolated enum LosslessDocumentRenderer {
    private static let pageSize = CGSize(width: 1240, height: 1754)
    private static let margin: CGFloat = 86
    private static let titleHeight: CGFloat = 78

    static func render(title: String, body: NSAttributedString) -> [UIImage] {
        guard body.length > 0 else { return [] }
        let content = NSMutableAttributedString()
        content.append(
            NSAttributedString(
                string: title + "\n",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 42, weight: .bold),
                    .foregroundColor: UIColor.label,
                ]
            ))
        content.append(body)
        return render(content)
    }

    static func monospaced(title: String, text: String) -> [UIImage] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 7
        let body = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 25, weight: .regular),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph,
            ]
        )
        return render(title: title, body: body)
    }

    static func prose(title: String, text: String) -> [UIImage] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 10
        paragraph.paragraphSpacing = 12
        let body = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 30),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph,
            ]
        )
        return render(title: title, body: body)
    }

    private static func render(_ attributedText: NSAttributedString) -> [UIImage] {
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        let bounds = CGRect(
            x: margin,
            y: margin,
            width: pageSize.width - margin * 2,
            height: pageSize.height - margin * 2
        )
        var location = 0
        var pages: [UIImage] = []

        while location < attributedText.length {
            let path = CGPath(rect: bounds, transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: location, length: 0),
                path,
                nil
            )
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else { break }

            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: pageSize, format: format).image { context in
                UIColor.systemBackground.setFill()
                context.fill(CGRect(origin: .zero, size: pageSize))
                let cg = context.cgContext
                cg.saveGState()
                cg.translateBy(x: 0, y: pageSize.height)
                cg.scaleBy(x: 1, y: -1)
                CTFrameDraw(frame, cg)
                cg.restoreGState()
            }
            pages.append(image)
            location += visible.length
        }
        return pages
    }
}

nonisolated enum StructuredJSONImporter {
    static func render(url: URL, title: String) throws -> [UIImage] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        _ = try JSONSerialization.jsonObject(with: data)
        let source =
            String(data: data, encoding: .utf8)
            ?? String(decoding: data, as: UTF8.self)
        return LosslessDocumentRenderer.monospaced(title: title, text: source)
    }
}

nonisolated enum StructuredPlistImporter {
    static func render(url: URL, title: String) throws -> [UIImage] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let text = describe(object, indent: 0)
        return LosslessDocumentRenderer.monospaced(title: title, text: text)
    }

    private static func describe(_ value: Any, indent: Int) -> String {
        let prefix = String(repeating: "  ", count: indent)
        if let dictionary = value as? [String: Any] {
            return dictionary.keys.sorted().map { key in
                let item = dictionary[key] as Any
                return "\(prefix)\(key):\n\(describe(item, indent: indent + 1))"
            }.joined(separator: "\n")
        }
        if let array = value as? [Any] {
            return array.enumerated().map { index, item in
                "\(prefix)[\(index)]\n\(describe(item, indent: indent + 1))"
            }.joined(separator: "\n")
        }
        return "\(prefix)\(String(describing: value))"
    }
}

nonisolated final class StructuredXMLImporter: NSObject, XMLParserDelegate {
    private struct NodeLine {
        let depth: Int
        let value: String
    }

    private var depth = 0
    private var pendingText = ""
    private var lines: [NodeLine] = []

    static func render(url: URL, title: String) throws -> [UIImage] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let delegate = StructuredXMLImporter()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? CocoaError(.fileReadCorruptFile)
        }
        delegate.flushText()
        let text = delegate.lines.map { line in
            String(repeating: "  ", count: line.depth) + line.value
        }.joined(separator: "\n")
        return LosslessDocumentRenderer.monospaced(title: title, text: text)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        flushText()
        let attributes = attributeDict.keys.sorted().map { key in
            "\(key)=\"\(attributeDict[key] ?? "")\""
        }.joined(separator: " ")
        let suffix = attributes.isEmpty ? "" : " " + attributes
        lines.append(NodeLine(depth: depth, value: "<\(elementName)\(suffix)>"))
        depth += 1
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        pendingText.append(string)
    }

    func parser(_ parser: XMLParser, foundCDATA cdataBlock: Data) {
        if let value = String(data: cdataBlock, encoding: .utf8) {
            pendingText.append(value)
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        flushText()
        depth = max(0, depth - 1)
        lines.append(NodeLine(depth: depth, value: "</\(elementName)>"))
    }

    private func flushText() {
        let value = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            lines.append(NodeLine(depth: depth, value: value))
        }
        pendingText = ""
    }
}

nonisolated enum TimedTextDocumentImporter {
    static func render(url: URL, title: String) throws -> [UIImage] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return LosslessDocumentRenderer.monospaced(title: title, text: text)
    }
}

nonisolated enum CalendarDocumentImporter {
    static func render(url: URL, title: String) throws -> [UIImage] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let source = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let events = source.components(separatedBy: "BEGIN:VEVENT").dropFirst().map { part in
            part.components(separatedBy: "END:VEVENT").first ?? part
        }
        let text = events.enumerated().map { index, event in
            let useful = event.split(whereSeparator: \.isNewline).filter {
                $0.hasPrefix("SUMMARY:") || $0.hasPrefix("DTSTART") || $0.hasPrefix("DTEND")
                    || $0.hasPrefix("LOCATION:") || $0.hasPrefix("DESCRIPTION:")
            }.joined(separator: "\n")
            return "Event \(index + 1)\n\(useful)"
        }.joined(separator: "\n\n")
        return LosslessDocumentRenderer.prose(title: title, text: text.isEmpty ? source : text)
    }
}
