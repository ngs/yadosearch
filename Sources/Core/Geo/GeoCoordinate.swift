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
