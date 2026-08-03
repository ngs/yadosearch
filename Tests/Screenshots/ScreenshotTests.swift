import XCTest
import YadoSearchUI

/// Walks the app through the screens that go on the App Store and writes a PNG
/// per screen, in whichever language and on whichever device the run was told
/// to use.
///
/// This is not a test in the assertion sense — it is the capture half of
/// `Scripts/screenshots.sh`, which starts the stub proxy, prepares the
/// simulator, runs this once per locale and collects the files. It still fails
/// loudly when a screen it expects never appears, because a run that silently
/// photographed the wrong screen is worse than one that stops.
///
/// Everything the app shows comes from `Scripts/screenshot-server.rb`, which
/// answers from the decoding tests' fixtures — so the same inns at the same
/// prices come out of every run, on every device, in both languages.
@MainActor
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private let timeout: TimeInterval = 60

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ScreenshotEnvironment.appArguments
    }

    func testCaptureScreenshots() throws {
        #if !os(macOS)
        // Before the launch, so the app lays out for the width it will be
        // photographed at rather than reflowing into it afterwards.
        if ScreenshotEnvironment.configuration.orientation == "landscape" {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        #endif
        app.launch()

        try captureSearchForm()
        try captureResults()
        try captureDetail()
        try capturePlans()
        try captureFavorites()
    }

    /// The search form, with a name typed in. The keyboard is dismissed first:
    /// half the screen behind it is the half worth showing.
    private func captureSearchForm() throws {
        let keyword = app.textFields[YadoAccessibilityID.searchKeyword]
        guard keyword.waitForExistence(timeout: timeout) else {
            XCTFail("The search form never appeared.")
            return
        }
        keyword.tap()
        keyword.typeText("東京駅")
        dismissKeyboard()
        settle()
        try capture("01_search")
    }

    /// The results, once the photographs have loaded — an inn list of grey
    /// placeholders is not a screenshot worth having.
    private func captureResults() throws {
        app.descendants(matching: .any)[YadoAccessibilityID.searchSubmit].firstMatch.tap()

        let firstRow = app.descendants(matching: .any)[YadoAccessibilityID.hotelRow(0)]
        guard firstRow.waitForExistence(timeout: timeout) else {
            XCTFail("The results list never appeared. Is Scripts/screenshot-server.rb running?")
            return
        }
        settle(seconds: 4)
        try capture("02_results")
    }

    /// One inn: the photograph, the map, the facts.
    private func captureDetail() throws {
        app.descendants(matching: .any)[YadoAccessibilityID.hotelRow(0)].tap()

        let favorite = app.descendants(matching: .any)[YadoAccessibilityID.hotelFavorite]
        guard favorite.waitForExistence(timeout: timeout) else {
            XCTFail("The detail screen never appeared.")
            return
        }
        // After the first load, not before it: the screen chooses its own
        // provider once the inn arrives, and a tap that lands earlier is undone
        // by that choice.
        settle(seconds: 3)
        selectJalan()
        settle(seconds: 4)
        try capture("03_detail")
    }

    /// The plans, further down the same screen, and the heart on the way past:
    /// the favourites shot needs something to have been favourited.
    private func capturePlans() throws {
        let favorite = app.descendants(matching: .any)[YadoAccessibilityID.hotelFavorite]
        if favorite.isHittable { favorite.tap() }

        // A soft wait: the identifier is on the section's container, and what
        // carries it into the tree differs by platform — on the Mac it may not
        // surface at all. The screen itself was already verified above, so this
        // is a pause for the plan search, not a gate.
        let plans = app.descendants(matching: .any)[YadoAccessibilityID.hotelPlans]
        _ = plans.waitForExistence(timeout: 15)
        // `scrollToElement` would stop as soon as the section's top edge is on
        // screen, which shows one plan and a lot of facts above it.
        scroll(times: 3)
        settle()
        try capture("04_plans")
    }

    /// The favourites tab, holding the inn just favourited.
    private func captureFavorites() throws {
        guard selectSecondTab() else {
            // The hierarchy differs enough between iPhone, iPad and Mac that a
            // bare failure here says nothing. Leave the tree behind.
            dumpHierarchy(named: "hierarchy-tabs.txt")
            XCTFail("Could not reach the second tab. The hierarchy is in the work directory.")
            return
        }
        settle(seconds: 3)
        try capture("05_favorites")
    }

    /// じゃらん, the first segment. It is what the plan list can show without a
    /// date; 楽天 asks for one, which is a correct screen and a dull photograph.
    private func selectJalan() {
        let jalan = app.descendants(matching: .any)[YadoAccessibilityID.hotelProvider("jalan")].firstMatch
        guard jalan.waitForExistence(timeout: 5), jalan.isHittable else {
            dumpHierarchy(named: "hierarchy-provider.txt")
            return
        }
        #if os(macOS)
        // A click *at a point* rather than on the element: the segments of an
        // NSSegmentedControl share one view, and an element-level click lands
        // on the control rather than inside the cell.
        jalan.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        #else
        jalan.tap()
        #endif
    }

    /// Leaves the element tree behind. The hierarchy differs enough between
    /// iPhone, iPad and Mac that "could not find it" on its own says nothing.
    private func dumpHierarchy(named name: String) {
        let url = ScreenshotEnvironment.workDirectory.appendingPathComponent(name)
        try? app.debugDescription.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Driving

    /// The app's second top-level place, お気に入り.
    ///
    /// By its symbol rather than its name: `Tab("お気に入り", systemImage:
    /// "heart")` puts the *symbol* in the identifier, which is the same word on
    /// the Japanese and the English pass, and it is there whether
    /// `TabView(.sidebarAdaptable)` drew a tab bar, a floating tab bar or a
    /// sidebar. Position is the fallback, for a shape none of that fits.
    private func selectSecondTab() -> Bool {
        let heart = app.descendants(matching: .any)["heart"].firstMatch
        if heart.waitForExistence(timeout: 5), heart.isHittable {
            heart.tap()
            return true
        }
        let candidates: [XCUIElementQuery] = [
            app.tabBars.firstMatch.buttons,
            app.outlines.firstMatch.cells,
            app.tables.firstMatch.cells
        ]
        for candidate in candidates where candidate.count > 1 {
            let element = candidate.element(boundBy: 1)
            if element.isHittable {
                element.tap()
                return true
            }
        }
        return false
    }

    /// Puts the keyboard away without running the search.
    ///
    /// Not with Return: the field's `onSubmit` searches, which is the *next*
    /// screenshot. A drag on the form is what dismisses it — and the form
    /// springs back to the top afterwards, so the shot is of the whole form.
    private func dismissKeyboard() {
        #if !os(macOS)
        guard !app.keyboards.allElementsBoundByIndex.isEmpty else { return }
        // The form dismisses the keyboard as soon as it scrolls
        // (`scrollDismissesKeyboard(.immediately)`); the swipe back down is what
        // returns it to the top, so the shot is of the whole form.
        app.swipeUp()
        app.swipeDown()
        #endif
    }

    private func scroll(times: Int) {
        for _ in 0 ..< times {
            #if os(macOS)
            // The window does not scroll; the scroll view inside it does — and
            // the first one is the sidebar's. The page is the widest.
            let scrollViews = app.scrollViews.allElementsBoundByIndex
            if let page = scrollViews.max(by: { $0.frame.width < $1.frame.width }) {
                page.scroll(byDeltaX: 0, deltaY: -600)
            }
            #else
            app.swipeUp()
            #endif
        }
    }

    /// Lets the screen finish arriving: an animation, a photograph, a plan
    /// search. Crude on purpose — there is nothing here to wait *for* that the
    /// app exposes, and a shot taken half a beat early is a shot wasted.
    private func settle(seconds: TimeInterval = 2) {
        Thread.sleep(forTimeInterval: seconds)
    }

    // MARK: - Capture

    /// Writes one PNG under the name the delivery step will sort by.
    private func capture(_ name: String) throws {
        let directory = ScreenshotEnvironment.workDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if ScreenshotEnvironment.configuration.externalCapture == true {
            try captureFromHost(name, in: directory)
            return
        }

        let screenshot = XCUIScreen.main.screenshot()
        let url = directory.appendingPathComponent("\(name).png")
        try screenshot.pngRepresentation.write(to: url)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Hands the capture over to the script and waits for it to finish.
    ///
    /// The two processes rendezvous through the work directory: the test drops
    /// a request, the script takes the shot with `screencapture` and drops the
    /// answer. The app is held still for as long as that takes, which is the
    /// point. Only macOS needs it — a UI test there flattens the window, and
    /// its rounded corners come back filled with black.
    private func captureFromHost(_ name: String, in directory: URL) throws {
        let request = directory.appendingPathComponent("capture-request-\(name)")
        let response = directory.appendingPathComponent("capture-done-\(name)")
        try? FileManager.default.removeItem(at: response)
        try Data().write(to: request)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: response.path) {
                try? FileManager.default.removeItem(at: response)
                return
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTFail("The script never answered the capture request for \(name).")
    }
}
