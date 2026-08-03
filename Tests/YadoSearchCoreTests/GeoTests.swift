import Testing
@testable import YadoSearchCore

@Suite("Coordinates and datums")
struct GeoTests {
    /// The Imperial Hotel Tokyo is the reference that pinned the datum down: the
    /// API places it at 35.669046 N, 139.761581 E, and the building stands at
    /// 35.67225 N, 139.75892 E on a WGS 84 map — ~400 m apart, the size of the
    /// Tokyo-datum shift over Kantō.
    @Test("The API's coordinates convert onto the WGS 84 position")
    func imperialHotelConvertsToWorldDatum() {
        let fromAPI = GeoCoordinate(latitude: 35.669046, longitude: 139.761581)
        let world = TokyoDatum.toWorld(fromAPI)

        #expect(abs(world.latitude - 35.67225) < 0.0005)
        #expect(abs(world.longitude - 139.75892) < 0.001)
    }

    @Test("Converting to WGS 84 and back returns the original")
    func roundTripsThroughWorldDatum() {
        let tokyo = GeoCoordinate(latitude: 35.669046, longitude: 139.761581)
        let roundTripped = TokyoDatum.fromWorld(TokyoDatum.toWorld(tokyo))

        #expect(abs(roundTripped.latitude - tokyo.latitude) < 0.00001)
        #expect(abs(roundTripped.longitude - tokyo.longitude) < 0.00001)
    }

    @Test("Thousandths of an arcsecond convert to degrees")
    func decodesTheAPICoordinateUnit() {
        #expect(abs(JalanCoordinateUnit.degrees(fromMilliseconds: 503_276_825) - 139.799118) < 0.000001)
        #expect(JalanCoordinateUnit.milliseconds(fromDegrees: 139.799118) == 503_276_825)
    }

    @Test("Distance between two points is metres")
    func measuresDistance() {
        let tokyoStation = GeoCoordinate(latitude: 35.681236, longitude: 139.767125)
        let shinagawa = GeoCoordinate(latitude: 35.628471, longitude: 139.738760)

        // ~6.4 km as the crow flies.
        #expect(abs(tokyoStation.distance(to: shinagawa) - 6_400) < 200)
    }
}
