import Foundation
import SwiftData
import YadoSearchCore

/// An inn the app has kept a copy of — either because the user favourited it, or
/// because they looked at it.
///
/// One model for both lists, as the 2010 release did (its `StoredItemManager`
/// backed `FavoriteManager` and `HistoryManager` alike): the two differ in how
/// they are trimmed and where they are shown, not in what they hold.
///
/// The record is a snapshot, not a reference. The directory search that produced
/// it is paged and filtered, and re-fetching a list of stored IDs would be one
/// request per inn — so keeping the fields is what makes both lists render
/// offline and instantly.
@Model
public final class StoredHotel {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        case favorite
        case history
    }

    /// `"favorite:300002"` — composite, because the same inn can legitimately be
    /// in both lists.
    ///
    /// Not `@Attribute(.unique)`: CloudKit mirroring forbids unique constraints.
    /// `StoredHotelStore` looks the identifier up before inserting instead, and
    /// every property carries a default because mirroring requires that too.
    public var id: String = ""
    public var kindRawValue: String = StoredHotel.Kind.history.rawValue
    public var hotelID: String = ""
    public var name: String = ""
    public var address: String = ""
    public var prefecture: String?
    public var largeArea: String?
    public var catchCopy: String?
    public var pictureURLString: String?
    public var latitude: Double?
    public var longitude: Double?
    /// When it was favourited, or last looked at.
    public var savedAt = Date.distantPast

    public init(
        kind: Kind,
        hotelID: String,
        name: String,
        address: String,
        prefecture: String? = nil,
        largeArea: String? = nil,
        catchCopy: String? = nil,
        pictureURLString: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        savedAt: Date = .now
    ) {
        id = Self.identifier(kind: kind, hotelID: hotelID)
        kindRawValue = kind.rawValue
        self.hotelID = hotelID
        self.name = name
        self.address = address
        self.prefecture = prefecture
        self.largeArea = largeArea
        self.catchCopy = catchCopy
        self.pictureURLString = pictureURLString
        self.latitude = latitude
        self.longitude = longitude
        self.savedAt = savedAt
    }

    public static func identifier(kind: Kind, hotelID: String) -> String {
        "\(kind.rawValue):\(hotelID)"
    }
}

public extension StoredHotel {
    convenience init(kind: Kind, hotel: Hotel, savedAt: Date = .now) {
        self.init(
            kind: kind,
            hotelID: hotel.id,
            name: hotel.name,
            address: hotel.address,
            prefecture: hotel.area.prefecture,
            largeArea: hotel.area.largeArea,
            catchCopy: hotel.catchCopy,
            pictureURLString: hotel.pictureURL?.absoluteString,
            latitude: hotel.coordinate?.latitude,
            longitude: hotel.coordinate?.longitude,
            savedAt: savedAt
        )
    }

    var kind: Kind { Kind(rawValue: kindRawValue) ?? .history }

    var pictureURL: URL? {
        pictureURLString.flatMap { URL(string: $0) }
    }

    var coordinate: GeoCoordinate? {
        guard let latitude, let longitude else { return nil }
        return GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    /// "東京都・浅草" — the two levels that actually place an inn for a reader.
    var areaSummary: String? {
        let summary = [prefecture, largeArea].compactMap { $0 }.joined(separator: "・")
        return summary.isEmpty ? nil : summary
    }

    /// Rebuilds enough of a `Hotel` to drive the detail screen. The fields a
    /// snapshot does not carry — access directions, check-in times — come back
    /// when the detail screen reloads the inn from the API.
    var hotel: Hotel {
        Hotel(
            id: hotelID,
            name: name,
            address: address,
            area: Hotel.Area(region: nil, prefecture: prefecture, largeArea: largeArea, smallArea: nil),
            catchCopy: catchCopy,
            pictureURL: pictureURL,
            coordinate: coordinate
        )
    }
}
