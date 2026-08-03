import Foundation

// The proxy's contract is `openapi.json` in the yadosearch-api repository, and
// these types are that contract in Swift. Names follow it exactly except where
// Swift spells something differently (`pictureUrl` → `pictureURL`), which is
// what the `CodingKeys` below are for.
//
// Everything optional here is optional in the contract too. The two upstream
// services describe an inn unevenly — a Jalan search carries access directions
// and check-in times, Rakuten carries the review score and the kana reading —
// and the proxy passes that unevenness through rather than inventing values.

/// One line of directions, e.g. label "東京駅より", detail "丸ノ内線…徒歩5分".
public struct Access: Sendable, Hashable, Codable, Identifiable {
    public let label: String
    public let detail: String

    public var id: String { label }
}

/// Where an inn sits in a provider's area hierarchy, by name. The codes that go
/// with these names come from `/v1/areas/jalan`.
public struct AreaNames: Sendable, Hashable, Codable {
    public let region: String?
    public let prefecture: String?
    public let large: String?
    public let small: String?
}

/// Per-aspect review scores. Rakuten scores each of these; Jalan does not.
public struct ReviewAspects: Sendable, Hashable, Codable {
    public let service: Double?
    public let location: Double?
    public let room: Double?
    public let equipment: Double?
    public let bath: Double?
    public let breakfast: Double?
    public let dinner: Double?
    public let cleanliness: Double?
}

public struct Review: Sendable, Hashable, Codable {
    public let average: Double
    public let count: Int?
    public let aspects: ReviewAspects?
}

/// A named group of facilities, e.g. label "館内設備", items ["大浴場", …].
public struct FacilityGroup: Sendable, Hashable, Codable, Identifiable {
    public let label: String
    public let items: [String]

    public var id: String { label }
}

/// The long tail of an inn's description. Only ever populated for Rakuten:
/// Jalan's search endpoints carry none of it, so a Jalan-sourced inn arrives
/// with this empty and the counterpart is where the substance is.
public struct HotelDetailFacts: Sendable, Hashable, Codable {
    public let telephone: String?
    public let reserveTelephone: String?
    public let fax: String?
    public let parking: String?
    public let roomCount: Int?
    public let facilities: [FacilityGroup]?
    public let languages: String?
    public let note: String?
    public let cancelPolicy: String?
    public let creditCards: [String]?
    public let privilege: String?
    public let otherInformation: String?
    public let userReview: String?
    public let reviewURL: URL?
    public let planListURL: URL?
    public let mapImageURL: URL?
    public let lastCheckIn: String?

    enum CodingKeys: String, CodingKey {
        case telephone, reserveTelephone, fax, parking, roomCount, facilities
        case languages, note, cancelPolicy, creditCards, privilege
        case otherInformation, userReview, lastCheckIn
        case reviewURL = "reviewUrl"
        case planListURL = "planListUrl"
        case mapImageURL = "mapImageUrl"
    }

    /// True when the provider sent nothing at all, which is the ordinary case
    /// for Jalan. Worth asking before drawing a section that would be empty.
    public var isEmpty: Bool { self == HotelDetailFacts() }

    init(
        telephone: String? = nil, reserveTelephone: String? = nil, fax: String? = nil,
        parking: String? = nil, roomCount: Int? = nil, facilities: [FacilityGroup]? = nil,
        languages: String? = nil, note: String? = nil, cancelPolicy: String? = nil,
        creditCards: [String]? = nil, privilege: String? = nil, otherInformation: String? = nil,
        userReview: String? = nil, reviewURL: URL? = nil, planListURL: URL? = nil,
        mapImageURL: URL? = nil, lastCheckIn: String? = nil
    ) {
        self.telephone = telephone
        self.reserveTelephone = reserveTelephone
        self.fax = fax
        self.parking = parking
        self.roomCount = roomCount
        self.facilities = facilities
        self.languages = languages
        self.note = note
        self.cancelPolicy = cancelPolicy
        self.creditCards = creditCards
        self.privilege = privilege
        self.otherInformation = otherInformation
        self.userReview = userReview
        self.reviewURL = reviewURL
        self.planListURL = planListURL
        self.mapImageURL = mapImageURL
        self.lastCheckIn = lastCheckIn
    }
}

/// One provider's whole account of an inn.
///
/// `id` is only meaningful together with `provider`; the two sites number their
/// inns independently.
public struct HotelProfile: Sendable, Hashable, Codable, Identifiable {
    public let provider: Provider
    public let id: String
    public let name: String
    public let nameKana: String?
    public let address: String?
    public let postalCode: String?
    public let area: AreaNames?
    public let kind: String?
    public let catchCopy: String?
    public let caption: String?
    public let pictureURL: URL?
    /// Already wrapped for the affiliate programme by the proxy. Open it in a
    /// browser; never fetch it.
    public let detailURL: URL?
    /// WGS 84. The proxy converts Jalan's Tokyo-datum coordinates on the way
    /// out, so nothing here has to know about the old datum.
    public let coordinate: GeoCoordinate?
    public let minimumCharge: Int?
    public let review: Review?
    public let access: [Access]?
    public let checkIn: String?
    public let checkOut: String?
    public let distanceMetres: Double?
    public let lastUpdate: String?
    public let detail: HotelDetailFacts?

    enum CodingKeys: String, CodingKey {
        case provider, id, name, nameKana, address, postalCode, area, kind
        case catchCopy, caption, coordinate, minimumCharge, review, access
        case checkIn, checkOut, distanceMetres, lastUpdate, detail
        case pictureURL = "pictureUrl"
        case detailURL = "detailUrl"
    }
}

/// What one provider will sell for an inn that a search returned.
public struct ProviderOffer: Sendable, Hashable, Codable, Identifiable {
    public let provider: Provider
    /// The inn's ID *on that provider*.
    public let id: String
    /// Affiliate-wrapped by the proxy.
    public let detailURL: URL?
    public let minimumCharge: Int?
    public let review: Review?

    enum CodingKeys: String, CodingKey {
        case provider, id, minimumCharge, review
        case detailURL = "detailUrl"
    }
}

/// One inn in a search result, with an offer per provider that carries it.
///
/// The proxy does the matching, so the same inn found on both sites arrives as
/// a single listing with two offers rather than as two rows.
public struct HotelListing: Sendable, Hashable, Codable, Identifiable {
    public let name: String
    public let address: String?
    public let area: AreaNames?
    public let kind: String?
    public let catchCopy: String?
    public let pictureURL: URL?
    public let coordinate: GeoCoordinate?
    public let checkIn: String?
    public let checkOut: String?
    public let access: [Access]?
    public let distanceMetres: Double?
    public let offers: [ProviderOffer]

    enum CodingKeys: String, CodingKey {
        case name, address, area, kind, catchCopy, coordinate
        case checkIn, checkOut, access, distanceMetres, offers
        case pictureURL = "pictureUrl"
    }

    /// Stable across pages and providers: the offers identify the inn, the name
    /// does not (two inns can share one).
    public var id: String {
        offers.map { "\($0.provider.rawValue):\($0.id)" }.sorted().joined(separator: "|")
    }

    public func offer(from provider: Provider) -> ProviderOffer? {
        offers.first { $0.provider == provider }
    }

    /// The cheapest quoted price, ignoring providers that quoted none.
    public var lowestCharge: Int? {
        offers.compactMap(\.minimumCharge).min()
    }
}

/// A search response, including what each provider failed to answer.
///
/// **A provider failing is not an error.** One side can time out, rate-limit or
/// refuse the query while the other answers; that arrives as results plus an
/// entry in `errors`, and the screen shows both.
public struct SearchResponse: Sendable, Hashable, Codable {
    public let results: [HotelListing]
    /// Hits per provider *before* merging, so these do not add up to
    /// `results.count` and routinely disagree with each other.
    public let totals: [Provider: Int]
    public let errors: [Provider: String]?

    public init(results: [HotelListing], totals: [Provider: Int], errors: [Provider: String]? = nil) {
        self.results = results
        self.totals = totals
        self.errors = errors
    }
}

/// One night of a plan: what it costs and, when the provider says so, how many
/// rooms are left.
public struct PlanNight: Sendable, Hashable, Codable, Identifiable {
    public let date: String
    public let rate: Int
    public let stock: Int?

    public var id: String { date }
}

public struct StayPlan: Sendable, Hashable, Codable, Identifiable {
    public let provider: Provider
    public let hotelID: String
    public let id: String
    public let name: String
    public let roomName: String?
    /// Affiliate-wrapped by the proxy.
    public let detailURL: URL?
    public let pictureURL: URL?
    public let caption: String?
    public let meal: String?
    public let rateType: String?
    /// Jalan's per-person guide price. Rakuten quotes no such thing.
    public let sampleRate: Int?
    public let checkIn: String?
    public let checkOut: String?
    public let facilities: [String]?
    public let nights: [PlanNight]?
    public let totalRate: Int?
    /// Set when only part of the stay could be priced.
    public let partial: Bool?
    public let planListURL: URL?

    enum CodingKeys: String, CodingKey {
        case provider, id, name, roomName, caption, meal, rateType
        case sampleRate, checkIn, checkOut, facilities, nights, totalRate, partial
        case hotelID = "hotelId"
        case detailURL = "detailUrl"
        case pictureURL = "pictureUrl"
        case planListURL = "planListUrl"
    }
}

public struct PlanPage: Sendable, Hashable, Codable {
    public let total: Int
    /// 1-based index of the first plan on this page.
    public let from: Int
    public let plans: [StayPlan]

    /// The page number to ask for next, or `nil` when this was the last one.
    ///
    /// Derived from what arrived rather than from the requested count, so a
    /// short final page ends the walk instead of asking for an empty one.
    public func nextPage(after page: Int) -> Int? {
        guard !plans.isEmpty, from + plans.count <= total else { return nil }
        return page + 1
    }
}

/// One inn as one provider sees it, plus the same inn on the other provider
/// when the proxy could match it.
public struct HotelDetailResponse: Sendable, Hashable, Codable {
    public let hotel: HotelProfile
    public let counterparts: [Provider: HotelProfile]?
    public let errors: [Provider: String]?

    /// The inn on `provider`, whether that is the one asked for or its match.
    public func profile(for provider: Provider) -> HotelProfile? {
        hotel.provider == provider ? hotel : counterparts?[provider]
    }

    /// Every provider this inn can be booked through, in a stable order.
    public var availableProviders: [Provider] {
        Provider.allCases.filter { profile(for: $0) != nil }
    }
}
