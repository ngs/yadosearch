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

    /// Both booking services refuse a coordinate outside Japan, so this is what
    /// a proximity search is checked against before it is offered at all.
    @Test(
        "Recognises the coordinates the booking services will answer about",
        arguments: [
            GeoCoordinate(latitude: 35.68, longitude: 139.77), // 東京
            GeoCoordinate(latitude: 45.42, longitude: 141.67), // 稚内
            GeoCoordinate(latitude: 26.21, longitude: 127.68), // 那覇
            GeoCoordinate(latitude: 24.45, longitude: 122.99) // 与那国
        ]
    )
    func recognisesJapan(_ coordinate: GeoCoordinate) {
        #expect(coordinate.isInJapan)
    }

    @Test(
        "Rejects the coordinates a reviewer abroad would search from",
        arguments: [
            GeoCoordinate(latitude: 37.33, longitude: -122.01), // Cupertino
            GeoCoordinate(latitude: 51.5, longitude: -0.12), // London
            GeoCoordinate(latitude: -33.87, longitude: 151.21), // Sydney
            GeoCoordinate(latitude: 21.3, longitude: -157.85) // Honolulu
        ]
    )
    func rejectsElsewhere(_ coordinate: GeoCoordinate) {
        #expect(!coordinate.isInJapan)
    }

    @Test("A point is no distance from itself")
    func measuresNothingFromItself() {
        let point = GeoCoordinate(latitude: 35.0, longitude: 139.0)

        #expect(point.distance(to: point) < 0.001)
    }
}
