import Foundation
import MapKit
import YadoSearchCore

/// A railway station the user can search around.
public struct Station: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    /// A line, an operator, or the surrounding locality — whatever MapKit knows
    /// that tells two identically named stations apart.
    public let subtitle: String?
    public let coordinate: GeoCoordinate

    public init(id: String, name: String, subtitle: String?, coordinate: GeoCoordinate) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.coordinate = coordinate
    }
}

/// Finds stations by name.
///
/// The Jalan API has no station parameter — it searches by area code, by inn name
/// or around a coordinate — so "inns near a station" is two steps: resolve the
/// station to a point with MapKit, then run a proximity search on that point.
public struct StationSearchService: Sendable {
    public init() {}

    public func search(_ text: String) async throws -> [Station] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.publicTransport])
        // Japan only: the service has no inns anywhere else, so a station in
        // another country would resolve to a search that always returns nothing.
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 137.5),
            span: MKCoordinateSpan(latitudeDelta: 22, longitudeDelta: 26)
        )

        let response = try await MKLocalSearch(request: request).start()
        // The region above is a hint, not a bound: MapKit will still answer with
        // a station on another continent when nothing here matches the name.
        return response.mapItems.compactMap(Station.init(mapItem:)).filter(\.coordinate.isInJapan)
    }
}

private extension Station {
    init?(mapItem: MKMapItem) {
        guard let name = mapItem.name else { return nil }
        let coordinate = mapItem.location.coordinate
        self.init(
            id: "\(name)@\(coordinate.latitude),\(coordinate.longitude)",
            name: name,
            subtitle: mapItem.address?.shortAddress,
            coordinate: GeoCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
        )
    }
}
