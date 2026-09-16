import Foundation
import Testing
@testable import Narabi

@Suite("Page model persistence")
struct PageModelPersistenceTests {
    @Test func roundTripsEveryEditableProperty() throws {
        let id = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let page = ProjectPage(
            id: id,
            originalData: Data([1, 2, 3]),
            renderedData: Data([4, 5, 6]),
            editBaseData: Data([7, 8]),
            outputStyle: .a4Centered,
            a4WidthRatio: 0.73,
            paperPreset: .b5,
            paperOrientation: .landscape,
            customPaperWidthMM: 123,
            customPaperHeightMM: 456,
            paperUnit: .centimeter,
            placementOffsetX: -0.4,
            placementOffsetY: 0.6,
            placementRotationDegrees: 91,
            colorMode: .monochrome,
            isHiddenFromPreviewAndOutput: true,
            cropInsets: PageCropInsets(left: 0.1, right: 0.2, top: 0.15, bottom: 0.05),
            placementBaseWidthMM: 88,
            sourceKind: .pdf,
            sourcePixelWidth: 1200,
            sourcePixelHeight: 1800,
            sourcePhysicalWidthMM: 210,
            sourcePhysicalHeightMM: 297,
            hasTrustedPhysicalSize: true)
        let data = try JSONEncoder().encode(page)
        let decoded = try JSONDecoder().decode(ProjectPage.self, from: data)
        #expect(decoded == page)
    }

    @Test func decodesLegacyPageWithSafeDefaults() throws {
        let json = "{\"originalData\":\"AQ==\",\"renderedData\":\"Ag==\"}"
        let page = try JSONDecoder().decode(ProjectPage.self, from: Data(json.utf8))
        #expect(page.outputStyle == .original)
        #expect(page.a4WidthRatio == 0.41)
        #expect(page.paperPreset == .a4)
        #expect(page.paperOrientation == .portrait)
        #expect(page.colorMode == .color)
        #expect(page.isHiddenFromPreviewAndOutput == false)
        #expect(page.cropInsets == PageCropInsets())
        #expect(page.sourceKind == .unknown)
        #expect(page.hasTrustedPhysicalSize == false)
    }

    @Test func projectPreservesEditorTrayAndDeletedOrder() throws {
        let first = page(byte: 1)
        let second = page(byte: 2)
        let tray = page(byte: 3)
        let deleted = page(byte: 4)
        var project = NarabiProject()
        project.pages = [second, first]
        project.tray = [tray]
        project.deleted = [deleted]
        let result = try JSONDecoder().decode(NarabiProject.self, from: JSONEncoder().encode(project))
        #expect(result.pages.map(\.id) == [second.id, first.id])
        #expect(result.tray.map(\.id) == [tray.id])
        #expect(result.deleted.map(\.id) == [deleted.id])
    }

    @Test func previewPrefersEditorThenTray() {
        let editor = page(byte: 1)
        let tray = page(byte: 2)
        var project = NarabiProject()
        project.pages = [editor]
        project.tray = [tray]
        #expect(project.previewItem?.id == editor.id)
        project.pages = []
        #expect(project.previewItem?.id == tray.id)
        project.tray = []
        #expect(project.previewItem == nil)
    }

    private func page(byte: UInt8) -> ProjectPage {
        ProjectPage(originalData: Data([byte]), renderedData: Data([byte]))
    }
}
