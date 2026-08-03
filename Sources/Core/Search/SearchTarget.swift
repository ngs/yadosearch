import Foundation

/// A point in Jalan's area hierarchy. The most specific code set wins: only one
/// level is sent, and the narrower one implies the ones above it.
///
/// Jalan's hierarchy and Rakuten's classification are different schemes with no
/// shared codes, so an area search reaches Jalan alone. The other three ways of
/// searching reach both.
public struct AreaSelection: Sendable, Hashable, Codable {
    public var regionID: String?
    public var prefectureID: String?
    public var largeAreaID: String?
    public var smallAreaID: String?

    public init(
        regionID: String? = nil,
        prefectureID: String? = nil,
        largeAreaID: String? = nil,
        smallAreaID: String? = nil
    ) {
        self.regionID = regionID
        self.prefectureID = prefectureID
        self.largeAreaID = largeAreaID
        self.smallAreaID = smallAreaID
    }
}

/// How far out a proximity search reaches.
///
/// The distances were measured against Jalan's opaque range codes — every
/// result of a search centred on Tokyo Station, at each code, with the farthest
/// inn recorded — and the proxy now takes metres directly. The labels still say
/// "about" because these five are the ones the app offers, not because the
/// number is uncertain.
///
/// **Rakuten caps its own search at 3 km** and rounds anything larger down, so
/// the wider settings widen the Jalan half of the results alone.
public enum SearchRadius: Int, Sendable, Hashable, CaseIterable, Identifiable, Codable {
    case aboutOneKilometre = 1
    case aboutTwoAndAHalfKilometres = 2
    case aboutFiveKilometres = 4
    case aboutSevenKilometres = 6
    case aboutTenKilometres = 8

    public var id: Int { rawValue }

    /// What is sent as `radius`, and what draws the search area on a map.
    public var approximateMetres: Double {
        switch self {
        case .aboutOneKilometre: 1_100
        case .aboutTwoAndAHalfKilometres: 2_500
        case .aboutFiveKilometres: 5_100
        case .aboutSevenKilometres: 7_300
        case .aboutTenKilometres: 10_000
        }
    }
}

/// What to search for. Exactly one of these; a request that names none of them
/// is refused.
public enum SearchTarget: Sendable, Hashable, Codable {
    /// Matches against the inn's name. Jalan refuses to answer when more than
    /// 200 inns match, so a bare "ホテル" comes back as an error rather than as
    /// a truncated list.
    case name(String)
    case area(AreaSelection)
    case around(GeoCoordinate, radius: SearchRadius)
}

/// Who is staying, and when.
public struct StayConditions: Sendable, Hashable, Codable {
    /// **Rakuten cannot be asked anything without one**; it has no undated
    /// mode. Jalan without one quotes guide prices instead.
    public var checkIn: Date?
    public var nights: Int
    public var rooms: Int
    public var party: GuestParty

    public init(
        checkIn: Date? = nil,
        nights: Int = 1,
        rooms: Int = 1,
        party: GuestParty = GuestParty()
    ) {
        self.checkIn = checkIn
        self.nights = max(nights, 1)
        self.rooms = max(rooms, 1)
        self.party = party
    }

    /// Both services run on Japan time, so a check-in date is broken up there
    /// rather than in whatever zone the device happens to be in.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()
}
