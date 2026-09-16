import CoreGraphics

nonisolated enum PaperOrientation: String, Codable, CaseIterable, Identifiable {
    case portrait, landscape
    var id: String { rawValue }
}

nonisolated enum PaperUnit: String, Codable, CaseIterable, Identifiable {
    case millimeter = "mm"
    case centimeter = "cm"
    case inch = "in"
    var id: String { rawValue }
    func displayValue(fromMM value: Double) -> Double {
        switch self {
        case .millimeter: value
        case .centimeter: value / 10
        case .inch: value / 25.4
        }
    }
    func millimeters(from value: Double) -> Double {
        switch self {
        case .millimeter: value
        case .centimeter: value * 10
        case .inch: value * 25.4
        }
    }
}

nonisolated enum PaperPreset: String, Codable, CaseIterable, Identifiable {
    case a3, a4, a5, b4, b5, letter, legal, postcard, photo4x6, custom
    var id: String { rawValue }
    var titleKey: String { "paper.\(rawValue)" }
    nonisolated var baseSizeMM: CGSize? {
        switch self {
        case .a3: CGSize(width: 297, height: 420)
        case .a4: CGSize(width: 210, height: 297)
        case .a5: CGSize(width: 148, height: 210)
        case .b4: CGSize(width: 250, height: 353)
        case .b5: CGSize(width: 176, height: 250)
        case .letter: CGSize(width: 215.9, height: 279.4)
        case .legal: CGSize(width: 215.9, height: 355.6)
        case .postcard: CGSize(width: 100, height: 148)
        case .photo4x6: CGSize(width: 101.6, height: 152.4)
        case .custom: nil
        }
    }
    nonisolated func sizeMM(orientation: PaperOrientation, customWidthMM: Double, customHeightMM: Double)
        -> CGSize
    {
        guard var result = baseSizeMM else { return CGSize(width: customWidthMM, height: customHeightMM) }
        if orientation == .landscape { result = CGSize(width: result.height, height: result.width) }
        return result
    }
}
