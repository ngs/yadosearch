import Foundation
import Testing
@testable import YadoSearchCore

@Suite("Coordinates")
struct GeoTests {
    /// Tokyo Station to the Tokyo Station Hotel, which stands inside it. The
    /// proxy reports 142 m for the same pair, measured server-side against a
    /// live search — so this is the figure the distance labels agree with.
    ///
    /// The datum conversion this suite used to pin down now happens in the
    /// proxy: everything the app sees is WGS 84.
    @Test("Measures the short distances the results screen shows")
    func measuresShortDistances() {
        let station = GeoCoordinate(latitude: 35.681236, longitude: 139.767125)
        let hotel = GeoCoordinate(latitude: 35.680661, longitude: 139.765715)

        let metres = station.distance(to: hotel)

        #expect(metres > 100)
        #expect(metres < 200)
    }

    @Test("A point is no distance from itself")
    func measuresNothingFromItself() {
        let point = GeoCoordinate(latitude: 35.0, longitude: 139.0)

        #expect(point.distance(to: point) < 0.001)
    }
}
