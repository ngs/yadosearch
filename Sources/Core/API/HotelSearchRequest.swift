import Foundation

/// What to search for, in the proxy's vocabulary.
///
/// Which providers answer follows from what is set, and is not chosen directly:
/// a keyword or a coordinate goes to both, Jalan area codes go to Jalan alone.
/// There is no parameter that says "only this provider".
public struct HotelSearchRequest: Sendable, Hashable {
    /// The inn's name. Both sides match on the name alone.
    public var keyword: String?
    /// WGS 84 — the proxy converts to whatever datum each provider wants.
    public var coordinate: GeoCoordinate?
    /// Metres. **Rakuten caps this at 3000** and rounds anything larger down;
    /// Jalan reaches about 10 km.
    public var radius: Int?

    public var jalanRegion: String?
    public var jalanPrefecture: String?
    public var jalanLargeArea: String?
    /// The finest level wins when more than one is set.
    public var jalanSmallArea: String?

    /// Flag names from `/v1/amenities`. **Jalan only** — Rakuten has no
    /// equivalent, so these do not narrow its half of the results.
    public var amenities: [String]
    /// 1 旅館 / 2 ペンション・民宿・ロッジ / 3 貸し別荘・コンドミニアム /
    /// 4 ホテル・ビジネスホテル / 5 公共の宿. Jalan only.
    public var hotelType: Int?
    /// Yen, per person per night. Jalan only.
    public var minRate: Int?
    public var maxRate: Int?
    /// 1 50音順 / 2 料金の安い順 / 3 料金の高い順 / 4 じゃらんnet人気順.
    /// Omitting it is what leaves a proximity search sorted nearest-first.
    public var order: Int?

    public var adults: Int?
    public var schoolChildren: Int?
    /// Jalan prices preschoolers in four bands and the total depends on which,
    /// so these are counted separately rather than summed.
    public var preschoolersWithBedAndMeal: Int?
    public var preschoolersWithMealOnly: Int?
    public var preschoolersWithBedOnly: Int?
    public var preschoolersWithNeither: Int?

    /// 1-based. **The same number goes to both providers**, so the merged page
    /// sizes do not line up.
    public var page: Int?
    /// Per provider, not per merged page.
    public var count: Int?

    public init(
        keyword: String? = nil,
        coordinate: GeoCoordinate? = nil,
        radius: Int? = nil,
        jalanRegion: String? = nil,
        jalanPrefecture: String? = nil,
        jalanLargeArea: String? = nil,
        jalanSmallArea: String? = nil,
        amenities: [String] = [],
        hotelType: Int? = nil,
        minRate: Int? = nil,
        maxRate: Int? = nil,
        order: Int? = nil,
        adults: Int? = nil,
        schoolChildren: Int? = nil,
        preschoolersWithBedAndMeal: Int? = nil,
        preschoolersWithMealOnly: Int? = nil,
        preschoolersWithBedOnly: Int? = nil,
        preschoolersWithNeither: Int? = nil,
        page: Int? = nil,
        count: Int? = nil
    ) {
        self.keyword = keyword
        self.coordinate = coordinate
        self.radius = radius
        self.jalanRegion = jalanRegion
        self.jalanPrefecture = jalanPrefecture
        self.jalanLargeArea = jalanLargeArea
        self.jalanSmallArea = jalanSmallArea
        self.amenities = amenities
        self.hotelType = hotelType
        self.minRate = minRate
        self.maxRate = maxRate
        self.order = order
        self.adults = adults
        self.schoolChildren = schoolChildren
        self.preschoolersWithBedAndMeal = preschoolersWithBedAndMeal
        self.preschoolersWithMealOnly = preschoolersWithMealOnly
        self.preschoolersWithBedOnly = preschoolersWithBedOnly
        self.preschoolersWithNeither = preschoolersWithNeither
        self.page = page
        self.count = count
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            items.append(URLQueryItem(name: name, value: value))
        }
        func add(_ name: String, _ value: Int?) {
            guard let value else { return }
            items.append(URLQueryItem(name: name, value: String(value)))
        }

        add("keyword", keyword)
        if let coordinate {
            add("latitude", String(coordinate.latitude))
            add("longitude", String(coordinate.longitude))
        }
        add("radius", radius)
        add("jalanRegion", jalanRegion)
        add("jalanPrefecture", jalanPrefecture)
        add("jalanLargeArea", jalanLargeArea)
        add("jalanSmallArea", jalanSmallArea)
        add("amenities", amenities.isEmpty ? nil : amenities.sorted().joined(separator: ","))
        add("hotelType", hotelType)
        add("minRate", minRate)
        add("maxRate", maxRate)
        add("order", order)
        add("adults", adults)
        add("schoolChildren", schoolChildren)
        add("preschoolersWithBedAndMeal", preschoolersWithBedAndMeal)
        add("preschoolersWithMealOnly", preschoolersWithMealOnly)
        add("preschoolersWithBedOnly", preschoolersWithBedOnly)
        add("preschoolersWithNeither", preschoolersWithNeither)
        add("page", page)
        add("count", count)
        return items
    }
}

public extension HotelSearchRequest {
    /// Builds a request from what the search screens collect.
    ///
    /// The filters and the party only reach Jalan — the proxy has nowhere to
    /// put them on the Rakuten side — so a filtered search returns a narrowed
    /// Jalan half and an unnarrowed Rakuten half. The results screen says so
    /// rather than pretending otherwise.
    init(
        target: SearchTarget,
        filters: SearchFilters = SearchFilters(),
        party: GuestParty? = nil,
        page: Int = 1,
        count: Int = 30
    ) {
        self.init(page: page, count: count)

        switch target {
        case let .name(text):
            keyword = text
        case let .area(selection):
            jalanRegion = selection.regionID
            jalanPrefecture = selection.prefectureID
            jalanLargeArea = selection.largeAreaID
            jalanSmallArea = selection.smallAreaID
        case let .around(centre, searchRadius):
            coordinate = centre
            radius = Int(searchRadius.approximateMetres)
        case .hotel:
            // A single inn is fetched by provider and ID, not searched for.
            break
        }

        amenities = filters.amenities.map(\.rawValue)
        hotelType = filters.hotelType?.rawValue
        minRate = filters.minimumRate
        maxRate = filters.maximumRate
        // `.unspecified` is 0, which the proxy would pass through as a sort
        // code. Leaving it out is what keeps a proximity search nearest-first.
        order = filters.sortOrder == .unspecified ? nil : filters.sortOrder.rawValue

        if let party {
            adults = party.adults
            schoolChildren = party.elementarySchoolChildren
            preschoolersWithBedAndMeal = party.preschoolersWithBedAndMeal
            preschoolersWithMealOnly = party.preschoolersWithMealOnly
            preschoolersWithBedOnly = party.preschoolersWithBedOnly
            preschoolersWithNeither = party.preschoolersWithNeither
        }
    }
}

/// The stay a plan search is priced for.
public struct StayRequest: Sendable, Hashable {
    /// **Required for Rakuten**, which has no undated mode. Jalan without one
    /// answers with guide prices instead of a bookable rate.
    public var checkIn: Date?
    public var nights: Int
    public var rooms: Int
    public var adults: Int

    public init(checkIn: Date? = nil, nights: Int = 1, rooms: Int = 1, adults: Int = 2) {
        self.checkIn = checkIn
        self.nights = nights
        self.rooms = rooms
        self.adults = adults
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let checkIn {
            items.append(URLQueryItem(name: "checkIn", value: Self.dayFormatter.string(from: checkIn)))
        }
        items.append(URLQueryItem(name: "nights", value: String(nights)))
        items.append(URLQueryItem(name: "rooms", value: String(rooms)))
        items.append(URLQueryItem(name: "adults", value: String(adults)))
        return items
    }
}
