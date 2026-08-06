import Foundation

/// A latitude/longitude pair in degrees.
///
/// Always WGS 84. Jalan reports its coordinates in the old Japanese datum, ~400
/// m away, but the proxy converts them before they ever reach the app — which
/// is why nothing here carries a datum of its own any more.
public struct GeoCoordinate: Sendable, Hashable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public extension GeoCoordinate {
    /// Whether this point is somewhere both booking services will answer about.
    ///
    /// Neither of them has anything outside Japan, and a proximity search on a
    /// foreign coordinate is refused by both — so this is what a search is
    /// checked against before it is run.
    ///
    /// The box is deliberately loose. It is meant to catch someone on another
    /// continent, not to trace a border: it spans Yonaguni to Minamitorishima
    /// and Okinotorishima to Etorofu, and takes in a fair amount of sea with
    /// them.
    var isInJapan: Bool {
        (20.0 ... 46.0).contains(latitude) && (122.0 ... 154.0).contains(longitude)
    }

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
