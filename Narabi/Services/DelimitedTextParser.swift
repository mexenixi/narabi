import Foundation

nonisolated enum DelimitedTextParser {
    static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\"" {
                let next = text.index(after: index)
                if quoted, next < text.endIndex, text[next] == "\"" {
                    field.append("\"")
                    index = next
                } else {
                    quoted.toggle()
                }
            } else if character == delimiter, !quoted {
                row.append(field)
                field = ""
            } else if character == "\n" || character == "\r" || character == "\r\n", !quoted {
                if character == "\r" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\n" { index = next }
                }
                row.append(field)
                rows.append(row)
                field = ""
                row = []
            } else {
                field.append(character)
            }
            index = text.index(after: index)
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
