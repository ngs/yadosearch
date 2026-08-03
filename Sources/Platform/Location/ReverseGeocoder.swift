import Foundation
import MapKit
import YadoSearchCore

/// Turns a coordinate into a place name a person recognises — "東京都千代田区"
/// rather than "35.6812, 139.7671".
///
/// Built on `MKReverseGeocodingRequest`, which is the replacement for
/// `CLGeocoder.reverseGeocodeLocation`; the Core Location API is deprecated as of
/// iOS 26 / macOS 26.
public struct ReverseGeocoder: Sendable {
    public init() {}

    /// A locality with just enough context to place it — the "Cupertino, CA"
    /// shape, which in Japan comes back as the ward and the prefecture.
    ///
    /// Returns `nil` rather than throwing: a name is decoration on a screen that
    /// works without it, and a failed lookup should leave the coordinate showing,
    /// not raise an error.
    public func placeName(for coordinate: GeoCoordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        // The names should read in the app's language, not the map region's.
        request.preferredLocale = Locale.current

        guard let mapItems = try? await request.mapItems, let item = mapItems.first else {
            return nil
        }
        // `.short` leaves the country off, which is noise for a Japan-only app.
        if let city = item.addressRepresentations?.cityWithContext(.short) {
            return city
        }
        return item.address?.shortAddress ?? item.address?.fullAddress
    }
}
