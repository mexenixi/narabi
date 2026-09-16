import CoreGraphics
import Foundation
import Testing
@testable import Narabi

@Suite("Paper and source compatibility")
struct PaperAndSourceCompatibilityTests {
    @Test func everyFixedPaperPresetHasExpectedMillimeterSize() {
        let expected: [(PaperPreset, Double, Double)] = [
            (.a3, 297, 420), (.a4, 210, 297), (.a5, 148, 210),
            (.b4, 250, 353), (.b5, 176, 250),
            (.letter, 215.9, 279.4), (.legal, 215.9, 355.6),
            (.postcard, 100, 148), (.photo4x6, 101.6, 152.4),
        ]
        for (preset, width, height) in expected {
            let size = preset.baseSizeMM
            #expect(abs((size?.width ?? 0) - width) < 0.000_001)
            #expect(abs((size?.height ?? 0) - height) < 0.000_001)
        }
        #expect(PaperPreset.custom.baseSizeMM == nil)
    }

    @Test func landscapeSwapsFixedPaperDimensions() {
        let portrait = PaperPreset.legal.sizeMM(orientation: .portrait, customWidthMM: 1, customHeightMM: 2)
        let landscape = PaperPreset.legal.sizeMM(orientation: .landscape, customWidthMM: 1, customHeightMM: 2)
        #expect(landscape.width == portrait.height)
        #expect(landscape.height == portrait.width)
    }

    @Test func customPaperUsesProvidedDimensions() {
        let portrait = PaperPreset.custom.sizeMM(orientation: .portrait, customWidthMM: 123, customHeightMM: 456)
        let landscape = PaperPreset.custom.sizeMM(orientation: .landscape, customWidthMM: 123, customHeightMM: 456)
        #expect(portrait == CGSize(width: 123, height: 456))
        #expect(landscape == CGSize(width: 123, height: 456))
    }

    @Test func systemPreviewKeepsLegacyPersistedRawValue() throws {
        #expect(ProjectPage.SourceKind.systemPreview.rawValue == "officePreview")
        let encoded = try JSONEncoder().encode(ProjectPage.SourceKind.systemPreview)
        let decoded = try JSONDecoder().decode(ProjectPage.SourceKind.self, from: encoded)
        #expect(decoded == .systemPreview)
        let legacy = Data([34] + Array("officePreview".utf8) + [34])
        #expect(try JSONDecoder().decode(ProjectPage.SourceKind.self, from: legacy) == .systemPreview)
    }

    @Test func allOtherSourceKindsRoundTrip() throws {
        for kind in [ProjectPage.SourceKind.unknown, .image, .pdf, .scan] {
            let encoded = try JSONEncoder().encode(kind)
            #expect(try JSONDecoder().decode(ProjectPage.SourceKind.self, from: encoded) == kind)
        }
    }
}
