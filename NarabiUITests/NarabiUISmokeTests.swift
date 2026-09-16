import XCTest

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

}
