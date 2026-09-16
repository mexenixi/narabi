import Foundation

nonisolated enum PageEditResultPolicy {
    nonisolated struct Settings {
        var outputStyle: ProjectPage.OutputStyle
        var a4WidthRatio: Double
        var paperPreset: PaperPreset
        var paperOrientation: PaperOrientation
        var customPaperWidthMM: Double
        var customPaperHeightMM: Double
        var paperUnit: PaperUnit
        var placementOffsetX: Double
        var placementOffsetY: Double
        var placementRotationDegrees: Double
        var colorMode: ProjectPage.ColorMode
        var cropInsets: PageCropInsets
    }

    nonisolated static func applying(
        to original: ProjectPage,
        editedData: Data,
        settings: Settings
    ) -> ProjectPage {
        var changed = original
        changed.editBaseData = editedData
        changed.renderedData = editedData
        changed.outputStyle = settings.outputStyle
        changed.a4WidthRatio = settings.a4WidthRatio
        changed.paperPreset = settings.paperPreset
        changed.paperOrientation = settings.paperOrientation
        changed.customPaperWidthMM = settings.customPaperWidthMM
        changed.customPaperHeightMM = settings.customPaperHeightMM
        changed.paperUnit = settings.paperUnit
        changed.placementOffsetX = settings.placementOffsetX
        changed.placementOffsetY = settings.placementOffsetY
        changed.placementRotationDegrees = settings.placementRotationDegrees
        changed.colorMode = settings.colorMode
        changed.cropInsets = settings.cropInsets
        return changed
    }
}
