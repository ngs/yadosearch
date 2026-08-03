import Foundation

/// A point in Jalan's area hierarchy. The most specific code set wins: the API
/// takes only one of `reg`/`pref`/`l_area`/`s_area`, and the narrower one implies
/// the ones above it.
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

    /// The query item for the narrowest level that is set.
    var queryItem: URLQueryItem? {
        if let smallAreaID { return URLQueryItem(name: "s_area", value: smallAreaID) }
        if let largeAreaID { return URLQueryItem(name: "l_area", value: largeAreaID) }
        if let prefectureID { return URLQueryItem(name: "pref", value: prefectureID) }
        if let regionID { return URLQueryItem(name: "reg", value: regionID) }
        return nil
    }
}

/// How far out a proximity search reaches.
///
/// The API takes an opaque code from 1 to 8 and does not publish what each one
/// means. The distances below were measured: every result of a search centred on
/// Tokyo Station was fetched at each code and the farthest one recorded, which
/// gives 1.1 / 2.5 / 5.1 / 7.3 / 10.0 km for the codes kept here. They are
/// approximations of an undocumented parameter, which is why the labels say
/// "about".
public enum SearchRadius: Int, Sendable, Hashable, CaseIterable, Identifiable, Codable {
    case aboutOneKilometre = 1
    case aboutTwoAndAHalfKilometres = 2
    case aboutFiveKilometres = 4
    case aboutSevenKilometres = 6
    case aboutTenKilometres = 8

    public var id: Int { rawValue }

    /// For drawing the search area on a map, and for sorting by distance.
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

/// What to search for. Exactly one of these; the API rejects a request that
/// names none of them.
public enum SearchTarget: Sendable, Hashable, Codable {
    /// Matches against the inn's name (`h_name`). The service refuses to answer
    /// when more than 200 inns match, so a bare "ホテル" comes back as an error
    /// rather than a truncated list.
    case name(String)
    case area(AreaSelection)
    case around(GeoCoordinate, radius: SearchRadius)
    case hotel(id: String)
}

extension SearchTarget {
    /// Coordinates go out in the Tokyo datum, which is the datum the service
    /// answers in. The `datum` parameter it documents makes no observable
    /// difference to either the request or the response, so converting here is
    /// what actually lines the search up with the results.
    var queryItems: [URLQueryItem] {
        switch self {
        case let .name(text):
            [URLQueryItem(name: "h_name", value: text)]
        case let .area(selection):
            selection.queryItem.map { [$0] } ?? []
        case let .around(coordinate, radius):
            {
                let tokyo = TokyoDatum.fromWorld(coordinate)
                return [
                    URLQueryItem(name: "x", value: String(JalanCoordinateUnit.milliseconds(fromDegrees: tokyo.longitude))),
                    URLQueryItem(name: "y", value: String(JalanCoordinateUnit.milliseconds(fromDegrees: tokyo.latitude))),
                    URLQueryItem(name: "range", value: String(radius.rawValue)),
                    URLQueryItem(name: "datum", value: "tokyo")
                ]
            }()
        case let .hotel(id):
            [URLQueryItem(name: "h_id", value: id)]
        }
    }
}

/// The most results one request may ask for.
public let jalanMaximumPageSize = 100

/// A search of the inn directory.
///
/// Leaving `filters.sortOrder` unspecified sends no `order` at all, which is
/// what makes a proximity search come back nearest-first.
public struct HotelSearchQuery: Sendable, Hashable {
    public var target: SearchTarget
    public var filters: SearchFilters
    /// Narrows to inns that can take this party. `nil` leaves occupancy out of
    /// it, which is what a plain "what is around here" search wants.
    public var party: GuestParty?
    /// 1-based index of the first result to return.
    public var start: Int
    public var count: Int

    public init(
        target: SearchTarget,
        filters: SearchFilters = SearchFilters(),
        party: GuestParty? = nil,
        start: Int = 1,
        count: Int = 30
    ) {
        self.target = target
        self.filters = filters
        self.party = party
        self.start = start
        self.count = min(max(count, 1), jalanMaximumPageSize)
    }

    var queryItems: [URLQueryItem] {
        target.queryItems
            + filters.queryItems
            + (party?.queryItems ?? [])
            + [
                URLQueryItem(name: "start", value: String(start)),
                URLQueryItem(name: "count", value: String(count))
            ]
    }
}

/// Who is staying, and when.
public struct StayConditions: Sendable, Hashable, Codable {
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

    /// The service runs on Japan time, so the check-in date is broken up there
    /// rather than in whatever zone the device happens to be in.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    var queryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "stay_count", value: String(nights)),
            URLQueryItem(name: "room_count", value: String(rooms))
        ] + party.queryItems
        if let checkIn {
            let parts = Self.calendar.dateComponents([.year, .month, .day], from: checkIn)
            if let year = parts.year, let month = parts.month, let day = parts.day {
                items += [
                    URLQueryItem(name: "stay_year", value: String(year)),
                    URLQueryItem(name: "stay_month", value: String(month)),
                    URLQueryItem(name: "stay_day", value: String(day))
                ]
            }
        }
        return items
    }
}

/// A search of the stay plans on offer.
public struct PlanSearchQuery: Sendable, Hashable {
    public var target: SearchTarget
    public var stay: StayConditions
    public var filters: SearchFilters
    public var start: Int
    public var count: Int

    public init(
        target: SearchTarget,
        stay: StayConditions = StayConditions(),
        filters: SearchFilters = SearchFilters(),
        start: Int = 1,
        count: Int = 30
    ) {
        self.target = target
        self.stay = stay
        self.filters = filters
        self.start = start
        self.count = min(max(count, 1), jalanMaximumPageSize)
    }

    var queryItems: [URLQueryItem] {
        target.queryItems + stay.queryItems + filters.queryItems + [
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "count", value: String(count))
        ]
    }
}
