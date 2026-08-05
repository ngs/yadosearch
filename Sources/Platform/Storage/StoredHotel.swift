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

    /// `"favorite:jalan:300002"` — composite, because the same inn can
    /// legitimately be in both lists, and because the two booking sites number
    /// their inns independently: `137869` means a different inn on each.
    ///
    /// Not `@Attribute(.unique)`: CloudKit mirroring forbids unique constraints.
    /// `StoredHotelStore` looks the identifier up before inserting instead, and
    /// every property carries a default because mirroring requires that too.
    public var id: String = ""
    public var kindRawValue: String = StoredHotel.Kind.history.rawValue
    public var providerRawValue: String = Provider.jalan.rawValue
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
        provider: Provider,
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
        id = Self.identifier(kind: kind, provider: provider, hotelID: hotelID)
        kindRawValue = kind.rawValue
        providerRawValue = provider.rawValue
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

    public static func identifier(kind: Kind, provider: Provider, hotelID: String) -> String {
        "\(kind.rawValue):\(provider.rawValue):\(hotelID)"
    }
}

public extension StoredHotel {
    convenience init(kind: Kind, hotel: HotelProfile, savedAt: Date = .now) {
        self.init(
            kind: kind,
            provider: hotel.provider,
            hotelID: hotel.id,
            name: hotel.name,
            address: hotel.address ?? "",
            prefecture: hotel.area?.prefecture,
            largeArea: hotel.area?.large,
            catchCopy: hotel.catchCopy,
            pictureURLString: hotel.pictureURL?.absoluteString,
            latitude: hotel.coordinate?.latitude,
            longitude: hotel.coordinate?.longitude,
            savedAt: savedAt
        )
    }

    var kind: Kind { Kind(rawValue: kindRawValue) ?? .history }

    /// Which site the stored inn belongs to. Records written before the app
    /// carried two providers have no value of their own and read as Jalan,
    /// which is what they were.
    var provider: Provider { Provider(rawValue: providerRawValue) ?? .jalan }

    var pictureURL: URL? {
        pictureURLString.flatMap { URL(string: $0) }
    }

    var coordinate: GeoCoordinate? {
        guard let latitude, let longitude else { return nil }
        return GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    /// "東京都・浅草" — the two levels that actually place an inn for a reader.
    var areaSummary: String? {
        let summary = [prefecture, largeArea].compactMap { $0 }.joined(separator: String(localized: " · "))
        return summary.isEmpty ? nil : summary
    }

    /// Everything the detail screen needs to open the inn. The rest of the
    /// record comes back when that screen fetches it.
    var reference: (provider: Provider, id: String) { (provider, hotelID) }
}
