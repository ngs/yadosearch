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
        choose(app.descendants(matching: .any)[YadoAccessibilityID.searchSubmit].firstMatch)

        let firstRow = row(0)
        guard firstRow.waitForExistence(timeout: timeout) else {
            XCTFail("The results list never appeared. Is Scripts/screenshot-server.rb running?")
            return
        }
        settle(seconds: 4)
        try capture("02_results")
    }

    /// One inn: the photograph, the map, the facts.
    private func captureDetail() throws {
        choose(row(0))

        let favorite = app.descendants(matching: .any)[YadoAccessibilityID.hotelFavorite]
        guard favorite.waitForExistence(timeout: timeout) else {
            dumpHierarchy(named: "hierarchy-after-row.txt")
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
        // On iPhone the split view is collapsed, so the inn was *pushed* and it
        // covers the tab bar. Walk back out before asking for another tab.
        popToRoot()
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

    /// A tap on iOS, a click on the Mac — and by coordinate, because an element
    /// the Mac does not consider hittable still has a point in the middle of it.
    private func choose(_ element: XCUIElement) {
        #if os(macOS)
        // The app has to be the active one first: a click into an inactive
        // macOS window activates it and goes no further, so the row would take
        // two clicks and the test only ever made one.
        app.activate()
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        #else
        element.tap()
        #endif
    }

    /// Unwinds whatever the run pushed, so the top-level places are reachable
    /// again. Harmless where nothing was pushed: there is no back button then.
    private func popToRoot() {
        for _ in 0 ..< 3 {
            // By identifier, not by position: an iPad has a navigation bar per
            // column, and the first one is not necessarily the one that was
            // pushed.
            let back = app.buttons["BackButton"].firstMatch
            guard back.exists, back.isHittable else { return }
            back.tap()
            settle(seconds: 1)
        }
    }

    /// A row of the results list. The identifier is on the row's content now
    /// that choosing an inn selects it rather than pushing it, and an
    /// identifier on content reaches every element inside it — so this asks for
    /// the cell, which is the one thing that can be tapped.
    private func row(_ index: Int) -> XCUIElement {
        let identifier = YadoAccessibilityID.hotelRow(index)
        // The row is a cell containing the identified labels — which is how it
        // is exposed on the Mac, where the labels themselves are not hittable
        // and the cell is what a click has to land on.
        let cell = app.cells.containing(.any, identifier: identifier).firstMatch
        if cell.exists, cell.frame.height > 1 {
            return cell
        }
        let matches = app.descendants(matching: .any).matching(identifier: identifier)
        // The photograph and the labels carry the identifier too, and so does a
        // zero-height scroll view on the Mac — which reports itself hittable
        // and then has no point to hit. The row is the one with a size.
        let sized = matches.allElementsBoundByIndex.filter {
            $0.frame.height > 1 && $0.frame.width > 1
        }
        // A row that can be tapped where there is one. On the Mac the list row
        // is not exposed at all — only the labels inside it carry the
        // identifier, and none of them is "hittable" — so the first one with a
        // real frame is what gets clicked, which selects the row it is in.
        // The biggest of them, not the first: the labels are stacked and some
        // are slivers, and a click has to land on the row rather than beside it.
        let biggest = sized.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        return sized.first { $0.isHittable } ?? biggest ?? matches.firstMatch
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
