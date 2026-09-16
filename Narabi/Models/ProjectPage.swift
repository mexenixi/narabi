import Foundation

nonisolated struct ProjectPage: Identifiable, Codable, Equatable {
    enum SourceKind: String, Codable {
        case unknown, image, pdf, scan
        case systemPreview = "officePreview"
    }
    enum ColorMode: String, Codable, CaseIterable { case color, grayscale, monochrome }
    enum OutputStyle: String, Codable {
        case original
        case a4Centered
    }

    var id = UUID()
    var originalData: Data
    var renderedData: Data
    var editBaseData: Data?
    var outputStyle: OutputStyle = .original
    var a4WidthRatio: Double = 0.41
    var paperPreset: PaperPreset = .a4
    var paperOrientation: PaperOrientation = .portrait
    var customPaperWidthMM: Double = 210
    var customPaperHeightMM: Double = 297
    var paperUnit: PaperUnit = .millimeter
    var placementOffsetX: Double = 0
    var placementOffsetY: Double = 0
    var placementRotationDegrees: Double = 0
    var colorMode: ColorMode = .color
    var isHiddenFromPreviewAndOutput = false
    var cropInsets = PageCropInsets()
    var placementBaseWidthMM: Double? = nil
    var sourceKind: SourceKind = .unknown
    var sourcePixelWidth: Int? = nil
    var sourcePixelHeight: Int? = nil
    var sourcePhysicalWidthMM: Double? = nil
    var sourcePhysicalHeightMM: Double? = nil
    var hasTrustedPhysicalSize = false

    enum CodingKeys: String, CodingKey {
        case id
        case originalData
        case renderedData
        case editBaseData
        case outputStyle
        case a4WidthRatio
        case paperPreset
        case paperOrientation
        case customPaperWidthMM
        case customPaperHeightMM
        case paperUnit
        case placementOffsetX
        case placementOffsetY
        case placementRotationDegrees
        case colorMode
        case isHiddenFromPreviewAndOutput, cropInsets, placementBaseWidthMM
        case sourceKind, sourcePixelWidth, sourcePixelHeight
        case sourcePhysicalWidthMM, sourcePhysicalHeightMM, hasTrustedPhysicalSize
    }

    init(
        id: UUID = UUID(),
        originalData: Data,
        renderedData: Data,
        editBaseData: Data? = nil,
        outputStyle: OutputStyle = .original,
        a4WidthRatio: Double = 0.41,
        paperPreset: PaperPreset = .a4,
        paperOrientation: PaperOrientation = .portrait,
        customPaperWidthMM: Double = 210,
        customPaperHeightMM: Double = 297,
        paperUnit: PaperUnit = .millimeter,
        placementOffsetX: Double = 0,
        placementOffsetY: Double = 0,
        placementRotationDegrees: Double = 0,
        colorMode: ColorMode = .color,
        isHiddenFromPreviewAndOutput: Bool = false,
        cropInsets: PageCropInsets = PageCropInsets(),
        placementBaseWidthMM: Double? = nil,
        sourceKind: SourceKind = .unknown,
        sourcePixelWidth: Int? = nil,
        sourcePixelHeight: Int? = nil,
        sourcePhysicalWidthMM: Double? = nil,
        sourcePhysicalHeightMM: Double? = nil,
        hasTrustedPhysicalSize: Bool = false
    ) {
        self.id = id
        self.originalData = originalData
        self.renderedData = renderedData
        self.editBaseData = editBaseData
        self.outputStyle = outputStyle
        self.a4WidthRatio = a4WidthRatio
        self.paperPreset = paperPreset
        self.paperOrientation = paperOrientation
        self.customPaperWidthMM = customPaperWidthMM
        self.customPaperHeightMM = customPaperHeightMM
        self.paperUnit = paperUnit
        self.placementOffsetX = placementOffsetX
        self.placementOffsetY = placementOffsetY
        self.placementRotationDegrees = placementRotationDegrees
        self.colorMode = colorMode
        self.isHiddenFromPreviewAndOutput = isHiddenFromPreviewAndOutput
        self.cropInsets = cropInsets
        self.placementBaseWidthMM = placementBaseWidthMM
        self.sourceKind = sourceKind
        self.sourcePixelWidth = sourcePixelWidth
        self.sourcePixelHeight = sourcePixelHeight
        self.sourcePhysicalWidthMM = sourcePhysicalWidthMM
        self.sourcePhysicalHeightMM = sourcePhysicalHeightMM
        self.hasTrustedPhysicalSize = hasTrustedPhysicalSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        originalData = try container.decode(Data.self, forKey: .originalData)
        renderedData = try container.decode(Data.self, forKey: .renderedData)
        editBaseData = try container.decodeIfPresent(Data.self, forKey: .editBaseData)
        outputStyle = try container.decodeIfPresent(OutputStyle.self, forKey: .outputStyle) ?? .original
        a4WidthRatio = try container.decodeIfPresent(Double.self, forKey: .a4WidthRatio) ?? 0.41
        paperPreset = try container.decodeIfPresent(PaperPreset.self, forKey: .paperPreset) ?? .a4
        paperOrientation =
            try container.decodeIfPresent(PaperOrientation.self, forKey: .paperOrientation) ?? .portrait
        customPaperWidthMM = try container.decodeIfPresent(Double.self, forKey: .customPaperWidthMM) ?? 210
        customPaperHeightMM = try container.decodeIfPresent(Double.self, forKey: .customPaperHeightMM) ?? 297
        paperUnit = try container.decodeIfPresent(PaperUnit.self, forKey: .paperUnit) ?? .millimeter
        placementOffsetX = try container.decodeIfPresent(Double.self, forKey: .placementOffsetX) ?? 0
        placementOffsetY = try container.decodeIfPresent(Double.self, forKey: .placementOffsetY) ?? 0
        placementRotationDegrees =
            try container.decodeIfPresent(Double.self, forKey: .placementRotationDegrees) ?? 0
        colorMode = try container.decodeIfPresent(ColorMode.self, forKey: .colorMode) ?? .color
        isHiddenFromPreviewAndOutput =
            try container.decodeIfPresent(Bool.self, forKey: .isHiddenFromPreviewAndOutput) ?? false
        cropInsets =
            try container.decodeIfPresent(PageCropInsets.self, forKey: .cropInsets) ?? PageCropInsets()
        placementBaseWidthMM = try container.decodeIfPresent(Double.self, forKey: .placementBaseWidthMM)
        sourceKind = try container.decodeIfPresent(SourceKind.self, forKey: .sourceKind) ?? .unknown
        sourcePixelWidth = try container.decodeIfPresent(Int.self, forKey: .sourcePixelWidth)
        sourcePixelHeight = try container.decodeIfPresent(Int.self, forKey: .sourcePixelHeight)
        sourcePhysicalWidthMM = try container.decodeIfPresent(Double.self, forKey: .sourcePhysicalWidthMM)
        sourcePhysicalHeightMM = try container.decodeIfPresent(Double.self, forKey: .sourcePhysicalHeightMM)
        hasTrustedPhysicalSize =
            try container.decodeIfPresent(Bool.self, forKey: .hasTrustedPhysicalSize) ?? false
    }
}
