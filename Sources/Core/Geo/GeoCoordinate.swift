import Foundation

/// A latitude/longitude pair in degrees, with no datum of its own — the datum is
/// whatever the producer says it is. Everything above `JalanAPIClient` deals in
/// WGS 84; `TokyoDatum` is the only place the other one exists.
public struct GeoCoordinate: Sendable, Hashable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public extension GeoCoordinate {
    /// Great-circle distance in metres, accurate enough for the "how far is this
    /// inn" label at the scales the app searches over (≤ 10 km).
    func distance(to other: GeoCoordinate) -> Double {
        let earthRadius = 6_371_008.8
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let haversine = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(haversine)))
    }
}

/// Conversions between the old Japanese datum and WGS 84.
///
/// The Jalan Web Service reports `<X>`/`<Y>` in the **Tokyo datum**, in
/// thousandths of an arcsecond. Nothing in the response says so, but it is
/// unambiguous from the data: the Imperial Hotel Tokyo comes back at
/// 35.669046 N, 139.761581 E, which is ~400 m from where it stands on a WGS 84
/// map and lands exactly on it once converted. Feeding those numbers straight to
/// MapKit would put every pin a block away from its building.
///
/// The transform is the standard degree-polynomial approximation of the
/// Tokyo→WGS 84 shift over Japan (good to a few metres inside the country, which
/// is the only place the API returns anything).
public enum TokyoDatum {
    public static func toWorld(_ coordinate: GeoCoordinate) -> GeoCoordinate {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        return GeoCoordinate(
            latitude: lat - 0.00010695 * lat + 0.000017464 * lon + 0.0046017,
            longitude: lon - 0.000046038 * lat - 0.000083043 * lon + 0.010040
        )
    }

    public static func fromWorld(_ coordinate: GeoCoordinate) -> GeoCoordinate {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        return GeoCoordinate(
            latitude: lat + 0.00010696 * lat - 0.000017467 * lon - 0.0046020,
            longitude: lon + 0.000046047 * lat + 0.000083049 * lon - 0.010041
        )
    }
}

/// The API's coordinate unit: thousandths of an arcsecond, as an integer.
public enum JalanCoordinateUnit {
    private static let perDegree = 3_600_000.0

    public static func degrees(fromMilliseconds value: Int) -> Double {
        Double(value) / perDegree
    }

    public static func milliseconds(fromDegrees value: Double) -> Int {
        Int((value * perDegree).rounded())
    }
}
