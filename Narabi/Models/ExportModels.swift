import Foundation

nonisolated enum ExportColorPolicy: String, Codable, CaseIterable, Identifiable {
    case perPage, allColor, allGrayscale, allMonochrome
    var id: String { rawValue }
}

nonisolated enum ExportPreset: String, Codable, CaseIterable, Identifiable {
    case pdf, jpeg, png, transparentPNG, photos
    var id: String { rawValue }
    var titleKey: String { "export.preset.\(rawValue)" }
    var symbol: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .jpeg: return "photo"
        case .png: return "photo.on.rectangle"
        case .transparentPNG: return "square.dashed"
        case .photos: return "photo.stack"
        }
    }
}

nonisolated enum ExportLongEdge: Int, Codable, CaseIterable, Identifiable {
    case px4096x4096 = -11
    case px3840x2160 = -10
    case px2560x1440 = -9
    case px2048x2048 = -8
    case px1920x1080 = -7
    case px1280x720 = -6
    case px1024x768 = -5
    case px800x600 = -4
    case px2752x2064 = -3
    case px2688x1242 = -2
    case custom = -1
    case original = 0
    case px1200 = 1200
    case px1600 = 1600
    case px1920 = 1920
    case px2048 = 2048
    case px2560 = 2560
    case px3072 = 3072
    case px3840 = 3840
    case px4096 = 4096
    case px7680 = 7680
    var id: Int { rawValue }
}

nonisolated struct ExportConfiguration: Codable, Equatable {
    var preset: ExportPreset = .pdf
    var longEdge: ExportLongEdge = .px2048
    var jpegQuality: Double = 0.88
}
