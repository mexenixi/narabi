import Foundation

nonisolated enum CompositeLayoutPolicy {
    static func workingPages(
        from pages: [ProjectPage],
        paperPreset: PaperPreset,
        paperOrientation: PaperOrientation,
        customWidthMM: Double,
        customHeightMM: Double,
        paperUnit: PaperUnit
    ) -> [ProjectPage] {
        pages.enumerated().map { index, page in
            var updated = page
            let hadSavedPlacement = page.outputStyle == .a4Centered
            if !hadSavedPlacement {
                updated.a4WidthRatio = index == 0 && isCompletelyUnedited(page) ? 1.0 : 0.40
                updated.placementOffsetX = 0
                updated.placementOffsetY = 0
                updated.placementRotationDegrees = 0
            }
            return applyingPaper(
                to: updated,
                paperPreset: paperPreset,
                paperOrientation: paperOrientation,
                customWidthMM: customWidthMM,
                customHeightMM: customHeightMM,
                paperUnit: paperUnit
            )
        }
    }

    static func isCompletelyUnedited(_ page: ProjectPage) -> Bool {
        page.originalData == page.renderedData && page.editBaseData == nil
            && page.cropInsets == PageCropInsets() && page.colorMode == .color
            && !page.isHiddenFromPreviewAndOutput
    }

    static func applyingPaper(
        to page: ProjectPage,
        paperPreset: PaperPreset,
        paperOrientation: PaperOrientation,
        customWidthMM: Double,
        customHeightMM: Double,
        paperUnit: PaperUnit
    ) -> ProjectPage {
        var updated = page
        updated.outputStyle = .a4Centered
        updated.paperPreset = paperPreset
        updated.paperOrientation = paperOrientation
        updated.customPaperWidthMM = customWidthMM
        updated.customPaperHeightMM = customHeightMM
        updated.paperUnit = paperUnit
        return updated
    }

    static func applyingPaper(
        to pages: [ProjectPage],
        paperPreset: PaperPreset,
        paperOrientation: PaperOrientation,
        customWidthMM: Double,
        customHeightMM: Double,
        paperUnit: PaperUnit
    ) -> [ProjectPage] {
        pages.map {
            applyingPaper(
                to: $0,
                paperPreset: paperPreset,
                paperOrientation: paperOrientation,
                customWidthMM: customWidthMM,
                customHeightMM: customHeightMM,
                paperUnit: paperUnit
            )
        }
    }

    static func togglingVisibility(in pages: [ProjectPage], id: UUID) -> [ProjectPage] {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return pages }
        var updated = pages
        updated[index].isHiddenFromPreviewAndOutput.toggle()
        return updated
    }

    static func moving(_ pages: [ProjectPage], from sourceIndex: Int, to destinationIndex: Int)
        -> [ProjectPage]
    {
        guard pages.indices.contains(sourceIndex) else { return pages }
        var updated = pages
        let page = updated.remove(at: sourceIndex)
        updated.insert(page, at: min(max(destinationIndex, 0), updated.count))
        return updated
    }
}
