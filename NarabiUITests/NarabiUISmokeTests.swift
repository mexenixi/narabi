import XCTest
import UIKit

final class NarabiUISmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(language: String, locale: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
        ]
        app.launch()
        return app
    }

    func testEnglishHomeSettingsAndNewProjectRoundTrip() {
        let app = launch(language: "en", locale: "en_US")
        XCTAssertTrue(app.buttons["home.newProject"].waitForExistence(timeout: 10))

        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.buttons["home.newProject"].waitForExistence(timeout: 5))

        app.buttons["home.newProject"].tap()
        XCTAssertTrue(app.buttons["import.back"].waitForExistence(timeout: 5))
        app.buttons["import.back"].tap()
        XCTAssertTrue(app.buttons["home.newProject"].waitForExistence(timeout: 5))
    }

    func testJapaneseHomeSettingsAndNewProjectRoundTrip() {
        let app = launch(language: "ja", locale: "ja_JP")
        XCTAssertTrue(app.buttons["home.newProject"].waitForExistence(timeout: 10))

        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        app.buttons["settings.done"].tap()

        app.buttons["home.newProject"].tap()
        XCTAssertTrue(app.buttons["import.back"].waitForExistence(timeout: 5))
        app.buttons["import.back"].tap()
        XCTAssertTrue(app.buttons["home.newProject"].waitForExistence(timeout: 5))
    }
    func testSupportScreenOpensInEnglish() {
        let app = launch(language: "en", locale: "en_US")
        XCTAssertTrue(app.buttons["home.support"].waitForExistence(timeout: 10))
        app.buttons["home.support"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["support.screen"].waitForExistence(timeout: 10))
    }

    func testContinueAddMenuOpensNewProjectAndReturns() {
        let app = launch(language: "ja", locale: "ja_JP")
        app.buttons["home.continue"].tap()
        XCTAssertTrue(app.buttons["projects.add"].waitForExistence(timeout: 5))

        app.buttons["projects.add"].tap()
        let newProject = app.buttons["新規プロジェクト"]
        XCTAssertTrue(newProject.waitForExistence(timeout: 5))
        newProject.tap()

        XCTAssertTrue(app.buttons["import.back"].waitForExistence(timeout: 5))
        app.buttons["import.back"].tap()
        XCTAssertTrue(app.buttons["projects.add"].waitForExistence(timeout: 5))
    }

    func testOpeningPDFCreatesProjectAndSelectionControlsDoNotOverlap() throws {
        let pdfURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NarabiShareSmoke-\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        try renderer.writePDF(to: pdfURL) { context in
            context.beginPage()
            ("Narabi import test" as NSString).draw(
                at: CGPoint(x: 72, y: 72),
                withAttributes: [.font: UIFont.systemFont(ofSize: 24)]
            )
        }

        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.open(pdfURL)

        let createProject = app.buttons["import.createProject"]
        XCTAssertTrue(createProject.waitForExistence(timeout: 30))
        XCTAssertTrue(createProject.isEnabled)
        createProject.tap()

        let ai = app.buttons["editor.aiSort"]
        XCTAssertTrue(ai.waitForExistence(timeout: 30))
        app.buttons["editor.selectionMode"].tap()
        let selectAll = app.buttons["全選択"]
        let clearAll = app.buttons["全解除"]
        XCTAssertTrue(selectAll.waitForExistence(timeout: 5))
        XCTAssertTrue(clearAll.waitForExistence(timeout: 5))
        XCTAssertTrue(selectAll.isHittable)
        XCTAssertTrue(clearAll.isHittable)
        XCTAssertFalse(ai.frame.intersects(selectAll.frame))
        XCTAssertFalse(ai.frame.intersects(clearAll.frame))
    }

}
