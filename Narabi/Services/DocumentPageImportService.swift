import Foundation
import UIKit
import ZIPFoundation

nonisolated enum DocumentImportSafetyError: LocalizedError {
    case inputFileTooLarge, tooManyArchiveEntries, archiveEntryTooLarge
    case archiveExpansionLimitExceeded, suspiciousCompressionRatio, generatedPageLimitExceeded

    var errorDescription: String? { "The document is too large or cannot be read safely." }
}

nonisolated private enum DocumentImportSafetyLimits {
    static let maximumInputFileBytes = 100 * 1024 * 1024
    static let maximumArchiveEntries = 10_000
    static let maximumEntryBytes = 50 * 1024 * 1024
    static let maximumExpandedBytes = 200 * 1024 * 1024
    static let maximumCompressionRatio: UInt64 = 2_000
    static let compressionRatioMinimumBytes = 1 * 1024 * 1024
    static let maximumGeneratedPages = 2_000
}

nonisolated private final class ArchiveExpansionBudget {
    private(set) var expandedBytes = 0
    func consume(_ byteCount: Int) throws {
        guard byteCount >= 0,
            expandedBytes <= DocumentImportSafetyLimits.maximumExpandedBytes - byteCount
        else { throw DocumentImportSafetyError.archiveExpansionLimitExceeded }
        expandedBytes += byteCount
    }
}

nonisolated enum DocumentPageImportService {
    static let supportedExtensions: Set<String> = [
        "docx", "xlsx", "pptx", "txt", "text", "md", "markdown",
        "csv", "tsv", "log", "json", "xml", "html", "htm", "yaml", "yml",
        "ics",
    ]

    static func canPageize(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func pageImages(for url: URL) throws -> [UIImage] {
        let ext = url.pathExtension.lowercased()
        let title = url.deletingPathExtension().lastPathComponent
        switch ext {
        case "docx":
            return try pageDOCX(url: url, title: title)
        case "xlsx":
            return try pageXLSX(url: url, title: title)
        case "pptx":
            return try pagePPTX(url: url, title: title)
        case "xml":
            return try StructuredXMLImporter.render(url: url, title: title)
        case "json":
            return try StructuredJSONImporter.render(url: url, title: title)
        case "ics":
            return try CalendarDocumentImporter.render(url: url, title: title)
        case "csv":
            return try pageDelimited(url: url, title: title, delimiter: ",")
        case "tsv":
            return try pageDelimited(url: url, title: title, delimiter: "\t")
        case "html", "htm":
            return try pageAttributed(url: url, title: title, type: .html)
        default:
            return try pagePlainText(url: url, title: title)
        }
    }

    private static func pagePlainText(url: URL, title: String) throws -> [UIImage] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard let text = decodeText(data) else { return [] }
        return DocumentTextPageRenderer.render(title: title, blocks: blocks(from: text))
    }

    private static func pageDelimited(
        url: URL,
        title: String,
        delimiter: Character
    ) throws -> [UIImage] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard let text = decodeText(data) else { return [] }
        let rows = DelimitedTextParser.parse(text, delimiter: delimiter)
        let blocks = rows.map { $0.joined(separator: "  |  ") }
        return DocumentTextPageRenderer.render(title: title, blocks: blocks)
    }

    private static func pageAttributed(
        url: URL,
        title: String,
        type: NSAttributedString.DocumentType
    ) throws -> [UIImage] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let attributed = try NSAttributedString(
            data: data,
            options: [.documentType: type],
            documentAttributes: nil
        )
        return DocumentTextPageRenderer.render(title: title, blocks: blocks(from: attributed.string))
    }

    private static func pageDOCX(url: URL, title: String) throws -> [UIImage] {
        let (archive, budget) = try validatedArchive(for: url)
        guard let data = try archiveData("word/document.xml", archive: archive, budget: budget)
        else { return [] }
        let parser = WordXMLParser()
        let groups = parser.parse(data)
        var images: [UIImage] = []
        for group in groups {
            try appendPages(DocumentTextPageRenderer.render(title: title, blocks: group), to: &images)
        }
        return images
    }

    private static func pagePPTX(url: URL, title: String) throws -> [UIImage] {
        let (archive, budget) = try validatedArchive(for: url)
        let paths = naturalSort(
            archive.map(\.path).filter {
                $0.hasPrefix("ppt/slides/slide") && $0.hasSuffix(".xml")
            }
        )
        var images: [UIImage] = []
        for (index, path) in paths.enumerated() {
            guard let data = try archiveData(path, archive: archive, budget: budget) else { continue }
            let blocks = SimpleTextXMLParser.parse(data, paragraphNames: ["p"], textNames: ["t"])
            try appendPages(
                DocumentTextPageRenderer.render(
                    title: "\(title) · \(index + 1)", blocks: blocks),
                to: &images
            )
        }
        return images
    }

    private static func pageXLSX(url: URL, title: String) throws -> [UIImage] {
        let (archive, budget) = try validatedArchive(for: url)
        let sharedStrings: [String]
        if let data = try archiveData("xl/sharedStrings.xml", archive: archive, budget: budget) {
            sharedStrings = SharedStringParser.parse(data)
        } else {
            sharedStrings = []
        }
        let paths = naturalSort(
            archive.map(\.path).filter {
                $0.hasPrefix("xl/worksheets/sheet") && $0.hasSuffix(".xml")
            }
        )
        var images: [UIImage] = []
        for (index, path) in paths.enumerated() {
            guard let data = try archiveData(path, archive: archive, budget: budget) else { continue }
            let rows = WorksheetParser(sharedStrings: sharedStrings).parse(data)
            let blocks = rows.map { $0.joined(separator: "  |  ") }
            try appendPages(
                DocumentTextPageRenderer.render(
                    title: "\(title) · Sheet \(index + 1)", blocks: blocks),
                to: &images
            )
        }
        return images
    }

    private static func validatedArchive(for url: URL) throws -> (Archive, ArchiveExpansionBudget) {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let size = values.fileSize, size > DocumentImportSafetyLimits.maximumInputFileBytes {
            throw DocumentImportSafetyError.inputFileTooLarge
        }
        let archive = try Archive(url: url, accessMode: .read)
        var count = 0
        for _ in archive {
            count += 1
            if count > DocumentImportSafetyLimits.maximumArchiveEntries {
                throw DocumentImportSafetyError.tooManyArchiveEntries
            }
        }
        return (archive, ArchiveExpansionBudget())
    }

    private static func archiveData(_ path: String, archive: Archive, budget: ArchiveExpansionBudget) throws
        -> Data?
    {
        guard let entry = archive[path] else { return nil }
        let declaredSize = Int(entry.uncompressedSize)
        guard declaredSize <= DocumentImportSafetyLimits.maximumEntryBytes else {
            throw DocumentImportSafetyError.archiveEntryTooLarge
        }
        let compressedSize = UInt64(entry.compressedSize)
        let uncompressedSize = UInt64(entry.uncompressedSize)
        if uncompressedSize >= UInt64(DocumentImportSafetyLimits.compressionRatioMinimumBytes),
            compressedSize > 0,
            uncompressedSize / compressedSize > DocumentImportSafetyLimits.maximumCompressionRatio
        {
            throw DocumentImportSafetyError.suspiciousCompressionRatio
        }
        var data = Data()
        data.reserveCapacity(declaredSize)
        _ = try archive.extract(entry) { chunk in
            guard data.count <= DocumentImportSafetyLimits.maximumEntryBytes - chunk.count else {
                throw DocumentImportSafetyError.archiveEntryTooLarge
            }
            try budget.consume(chunk.count)
            data.append(chunk)
        }
        return data
    }

    private static func appendPages(_ pages: [UIImage], to images: inout [UIImage]) throws {
        guard images.count <= DocumentImportSafetyLimits.maximumGeneratedPages - pages.count else {
            throw DocumentImportSafetyError.generatedPageLimitExceeded
        }
        images.append(contentsOf: pages)
    }

    private static func decodeText(_ data: Data) -> String? {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        if data.starts(with: [0xFF, 0xFE]) {
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }

        let sample = data.prefix(4096)
        let evenNulls = sample.enumerated().filter { $0.offset.isMultiple(of: 2) && $0.element == 0 }.count
        let oddNulls = sample.enumerated().filter { !$0.offset.isMultiple(of: 2) && $0.element == 0 }.count
        let threshold = max(sample.count / 10, 2)
        if oddNulls >= threshold, let value = String(data: data, encoding: .utf16LittleEndian) {
            return value
        }
        if evenNulls >= threshold, let value = String(data: data, encoding: .utf16BigEndian) {
            return value
        }
        if let shiftJIS = String(data: data, encoding: .shiftJIS) { return shiftJIS }

        var converted: NSString?
        let detected = NSString.stringEncoding(
            for: data,
            encodingOptions: [.suggestedEncodingsKey: [String.Encoding.shiftJIS.rawValue]],
            convertedString: &converted,
            usedLossyConversion: nil
        )
        if detected != 0, let converted { return converted as String }
        return String(data: data, encoding: .isoLatin1)
    }

    private static func blocks(from text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\u{000C}")
            .flatMap { section in
                section.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
    }

    private static func naturalSort(_ paths: [String]) -> [String] {
        paths.sorted { left, right in
            left.localizedStandardCompare(right) == .orderedAscending
        }
    }
}
