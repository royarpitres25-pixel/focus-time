import XCTest

/// Walks through a real focus round with the short Debug timers
/// (15-second focus, 10-second break).
///
/// To save screenshots of each step to a folder, run with
/// `TEST_RUNNER_FT_SHOTS=/path/to/folder xcodebuild test ...`.
final class FocusFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-useTestTimers", "YES"]
    }

    func testFullRoundIsRecorded() {
        app.launch()
        returnToIdle()
        snapshot("01-idle")

        let historyBefore = historyRowCount()
        startFocus(named: "Read chapter 4")
        snapshot("02-focusing")

        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 3))
        snapshot("03-paused")
        app.buttons["Resume"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 3))

        // The 15-second focus finishes on its own.
        XCTAssertTrue(app.buttons["Done for Now"].waitForExistence(timeout: 30))
        sleep(3)
        snapshot("04-focus-done")

        // The break only starts when asked.
        let breakButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Take a'")).firstMatch
        XCTAssertTrue(breakButton.exists)
        breakButton.tap()
        XCTAssertTrue(app.buttons["End Break"].waitForExistence(timeout: 3))
        snapshot("05-on-break")

        XCTAssertTrue(app.buttons["Focus Again"].waitForExistence(timeout: 25))
        snapshot("06-break-over")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Start Focus"].waitForExistence(timeout: 3))

        XCTAssertEqual(historyRowCount(), historyBefore + 1, "A completed focus is saved to history")
        app.buttons["History"].firstMatch.tap()
        sleep(1)
        snapshot("07-history")
        openFocusTab()
    }

    func testCancelledFocusIsNotRecorded() {
        app.launch()
        returnToIdle()
        let historyBefore = historyRowCount()

        startFocus(named: "Quick test")
        app.buttons["Cancel"].tap()
        let confirm = app.buttons["Cancel Focus"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        snapshot("08-cancel-confirm")
        confirm.tap()

        XCTAssertTrue(app.buttons["Start Focus"].waitForExistence(timeout: 3))
        XCTAssertEqual(historyRowCount(), historyBefore, "Cancelling never records a session")
    }

    func testTimerSurvivesRelaunch() {
        app.launch()
        returnToIdle()
        startFocus(named: "Relaunch check")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5), "The running focus is restored after relaunch")
        let name = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Relaunch check"))
            .firstMatch
        XCTAssertTrue(name.exists, "The session name is restored too")

        cancelIfNeeded()
    }

    func testZLiveActivityOutsideTheApp() {
        app.launch()
        returnToIdle()
        startFocus(named: "Write essay intro")

        XCUIDevice.shared.press(.home)
        sleep(2)
        snapshot("09-dynamic-island", screen: true)

        let lock = NSSelectorFromString("pressLockButton")
        if XCUIDevice.shared.responds(to: lock) {
            XCUIDevice.shared.perform(lock)
            sleep(2)
            XCUIDevice.shared.press(.home)
            sleep(2)
            // First run only: let the system show Live Activities.
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let allow = springboard.buttons["Allow"]
            if allow.waitForExistence(timeout: 2) {
                allow.tap()
                sleep(2)
            }
            snapshot("10-lock-screen", screen: true)
        }

        app.activate()
        _ = app.buttons["Pause"].waitForExistence(timeout: 5)
        cancelIfNeeded()
    }

    // MARK: - Helpers

    private func startFocus(named name: String) {
        openFocusTab()
        let field = app.textFields["Session name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let clear = app.buttons["Clear name"]
        if clear.exists { clear.tap() } else { field.tap() }
        field.typeText(name)
        app.buttons["Start Focus"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 3))
    }

    private func openFocusTab() {
        let tab = app.buttons["Focus"].firstMatch
        if tab.exists { tab.tap() }
    }

    private func returnToIdle() {
        openFocusTab()
        cancelIfNeeded()
        for label in ["End Break", "Done", "Done for Now"] where app.buttons[label].exists {
            app.buttons[label].tap()
        }
        if app.buttons["Done"].waitForExistence(timeout: 1) { app.buttons["Done"].tap() }
        XCTAssertTrue(app.buttons["Start Focus"].waitForExistence(timeout: 5))
    }

    private func cancelIfNeeded() {
        guard app.buttons["Cancel"].exists else { return }
        app.buttons["Cancel"].tap()
        if app.buttons["Cancel Focus"].waitForExistence(timeout: 3) {
            app.buttons["Cancel Focus"].tap()
        }
    }

    /// Today's completed session count, read from the History summary card
    /// ("Today: 25 minutes focused, 1 sessions").
    private func historyRowCount() -> Int {
        app.buttons["History"].firstMatch.tap()
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Today:'"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let label = card.label
        openFocusTab()
        guard let sessionsPart = label.split(separator: ",").last else { return -1 }
        let digits = sessionsPart.filter(\.isNumber)
        return Int(digits) ?? -1
    }

    private func snapshot(_ name: String, screen: Bool = false) {
        let shot = screen ? XCUIScreen.main.screenshot() : app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let folder = ProcessInfo.processInfo.environment["FT_SHOTS"] {
            let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "device"
            let file = URL(fileURLWithPath: folder)
                .appendingPathComponent("\(device.replacingOccurrences(of: " ", with: "-"))-\(name).png")
            try? shot.pngRepresentation.write(to: file)
        }
    }
}
