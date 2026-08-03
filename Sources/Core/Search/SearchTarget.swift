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

/// A point in Rakuten's classification: 大区分 → 中区分 → 小区分 → 細区分.
///
/// Unlike Jalan's, the levels above the small class cannot be searched on their
/// own — Rakuten answers `specify valid anyone set of parameters from
/// classcodes[…]` to a query that stops at the middle class, and `specify valid
/// detailClassCode` to a small class that has detail classes. So the three
/// upper levels are required here and only `detailClassCode` is optional, which
/// is also why there is no Rakuten equivalent of searching "東京都" whole.
public struct RakutenAreaSelection: Sendable, Hashable, Codable {
    public var largeClassCode: String
    public var middleClassCode: String
    public var smallClassCode: String
    public var detailClassCode: String?

    public init(
        largeClassCode: String,
        middleClassCode: String,
        smallClassCode: String,
        detailClassCode: String? = nil
    ) {
        self.largeClassCode = largeClassCode
        self.middleClassCode = middleClassCode
        self.smallClassCode = smallClassCode
        self.detailClassCode = detailClassCode
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
    /// Jalan's hierarchy. The case is spelled `area` rather than `jalanArea`
    /// because recent searches are stored as this enum's JSON, and a case name
    /// is what that JSON is keyed by: renaming it would drop every stored area
    /// search on the floor.
    case area(AreaSelection)
    case rakutenArea(RakutenAreaSelection)
    case around(GeoCoordinate, radius: SearchRadius)

    /// The scope this target can only be searched at, or `nil` when it reaches
    /// both providers and the choice is the searcher's.
    ///
    /// Area codes belong to one scheme or the other; there is nothing to send
    /// the provider whose codes were not picked.
    public var requiredScope: SearchScope? {
        switch self {
        case .name, .around: nil
        case .area: .jalan
        case .rakutenArea: .rakuten
        }
    }
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
}
