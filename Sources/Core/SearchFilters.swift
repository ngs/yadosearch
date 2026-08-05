import Foundation

/// How results are ordered.
///
/// The codes are undocumented, but the 2010 release shipped their meanings in
/// `FilterConditions_jalan.plist` and the service still honours all five.
public enum HotelSortOrder: Int, Sendable, Hashable, CaseIterable, Identifiable, Codable {
    case unspecified = 0
    case kana = 1
    case rateAscending = 2
    case rateDescending = 3
    case popularity = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .unspecified: String(localized: "Any")
        case .kana: String(localized: "Kana order")
        case .rateAscending: String(localized: "Guide price, low to high")
        case .rateDescending: String(localized: "Guide price, high to low")
        case .popularity: String(localized: "Jalan net popularity")
        }
    }
}

/// 宿の種類 (`h_type`).
public enum HotelType: Int, Sendable, Hashable, CaseIterable, Identifiable, Codable {
    case japaneseInn = 1
    case pensionOrGuesthouse = 2
    case rentalVillaOrCondominium = 3
    case hotel = 4
    case publicLodging = 5

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .japaneseInn: String(localized: "Ryokan")
        case .pensionOrGuesthouse: String(localized: "Pension, guesthouse or lodge")
        case .rentalVillaOrCondominium: String(localized: "Villa or condominium")
        case .hotel: String(localized: "Hotel or business hotel")
        case .publicLodging: String(localized: "Public lodging")
        }
    }
}

/// A yes/no condition an inn can satisfy — each one a flag parameter that is
/// sent as `1` when on and omitted when off.
///
/// The vocabulary is Jalan's, taken from the parameter list the 2010 release
/// shipped with (`Misc/docs/jws.txt` and `FilterConditions_jalan.plist`), and the
/// Japanese names are the service's own wording rather than a translation — which
/// is why they live here next to the codes instead of in the UI layer.
public enum Amenity: String, Sendable, Hashable, CaseIterable, Identifiable, Codable {
    // 風呂
    case publicBath = "pub_bath"
    case hotSpring = "onsen"
    case privateBath = "prv_bath"
    case viewBath = "v_bath"
    case openAirBath = "o_bath"
    case sauna = "sauna"
    case jacuzzi = "jacz"
    case massage = "mssg"
    case esthetics = "esthe"
    case freeFlowingSpring = "pour"
    case cloudySpring = "cloudy"

    // 部屋・宿
    case nonSmokingRoom = "no_smk"
    case inRoomInternet = "net"
    case roomWithOpenAirBath = "r_room"
    case highClass = "high"
    case pointDiscount = "p_ok"
    case suiteOrDetachedRoom = "sp_room"
    case bathAndToilet = "bath_to"

    // 施設・遊び
    case tableTennis = "p_pong"
    case skiRental = "r_ski"
    case snowboardRental = "r_brd"
    case outdoorPool = "o_pool"
    case indoorPool = "i_pool"
    case fitnessGym = "fitness"
    case sportsHall = "gym"
    case sportsField = "p_field"
    case barbecue = "bbq"
    case banquetHall = "hall"

    // 立地
    case withinFiveMinutesOfStation = "5_station"
    case withinFiveMinutesOfBeach = "5_beach"
    case withinFiveMinutesOfSlope = "5_slope"
    case withinFiveMinutesOfConvenienceStore = "cvs"

    // サービス
    case breakfastInRoom = "room_b"
    case dinnerInRoom = "room_d"
    case breakfastInPrivateRoom = "prv_b"
    case dinnerInPrivateRoom = "prv_d"
    case earlyCheckIn = "early_in"
    case lateCheckOut = "late_out"
    case freeParking = "parking"
    case shuttleService = "limo"
    case petsAllowed = "pet"

    // 食事・部屋タイプ
    case planWithoutMeals = "no_meal"
    case breakfastOnlyPlan = "b_only"
    case dinnerOnlyPlan = "d_only"
    case twoMealsPlan = "2_meals"
    case singleRoom = "sng_room"
    case twinRoom = "twn_room"
    case doubleRoom = "dbl_room"
    case tripleRoom = "tri_room"
    case fourBedRoom = "4bed_room"
    case japaneseStyleRoom = "jpn_room"
    case japaneseWesternRoom = "j_w_room"

    // 子ども対応
    case childRate = "child_price"
    case elementarySchoolRate = "c_sc"
    case preschoolerBedAndMeal = "c_bed_meal"
    case preschoolerNeither = "c_no_bed_meal"
    case preschoolerMealOnly = "c_meal_only"
    case preschoolerBedOnly = "c_bed_only"

    // クレジットカード
    case creditCard = "c_card"
    case cardJCB = "c_jcb"
    case cardVisa = "c_visa"
    case cardMastercard = "c_master"
    case cardAmex = "c_amex"
    case cardUC = "c_uc"
    case cardDC = "c_dc"
    case cardNICOS = "c_nicos"
    case cardDiners = "c_diners"
    case cardSaison = "c_saison"
    case cardUFJ = "c_ufj"

    public var id: String { rawValue }

    public enum Group: String, Sendable, Hashable, CaseIterable, Identifiable, Codable {
        case bath = "Bath"
        case room = "Room and property"
        case facilities = "Facilities and activities"
        case location = "Location"
        case service = "Service"
        case mealsAndRooms = "Meals and room types"
        case children = "For children"
        case creditCards = "Credit cards"

        public var id: String { rawValue }
        /// The raw value is the Japanese name, and doubles as the key the
        /// String Catalog translates.
        public var title: String { String(localized: String.LocalizationValue(rawValue)) }

        public var amenities: [Amenity] {
            Amenity.allCases.filter { $0.group == self }
        }
    }

    public var group: Group {
        switch self {
        case .publicBath, .hotSpring, .privateBath, .viewBath, .openAirBath,
             .sauna, .jacuzzi, .massage, .esthetics, .freeFlowingSpring, .cloudySpring:
            .bath
        case .nonSmokingRoom, .inRoomInternet, .roomWithOpenAirBath, .highClass,
             .pointDiscount, .suiteOrDetachedRoom, .bathAndToilet:
            .room
        case .tableTennis, .skiRental, .snowboardRental, .outdoorPool, .indoorPool,
             .fitnessGym, .sportsHall, .sportsField, .barbecue, .banquetHall:
            .facilities
        case .withinFiveMinutesOfStation, .withinFiveMinutesOfBeach,
             .withinFiveMinutesOfSlope, .withinFiveMinutesOfConvenienceStore:
            .location
        case .breakfastInRoom, .dinnerInRoom, .breakfastInPrivateRoom, .dinnerInPrivateRoom,
             .earlyCheckIn, .lateCheckOut, .freeParking, .shuttleService, .petsAllowed:
            .service
        case .planWithoutMeals, .breakfastOnlyPlan, .dinnerOnlyPlan, .twoMealsPlan,
             .singleRoom, .twinRoom, .doubleRoom, .tripleRoom, .fourBedRoom,
             .japaneseStyleRoom, .japaneseWesternRoom:
            .mealsAndRooms
        case .childRate, .elementarySchoolRate, .preschoolerBedAndMeal,
             .preschoolerNeither, .preschoolerMealOnly, .preschoolerBedOnly:
            .children
        case .creditCard, .cardJCB, .cardVisa, .cardMastercard, .cardAmex, .cardUC,
             .cardDC, .cardNICOS, .cardDiners, .cardSaison, .cardUFJ:
            .creditCards
        }
    }

    public var title: String {
        switch self {
        case .publicBath: String(localized: "Indoor or large communal bath")
        case .hotSpring: String(localized: "Hot spring")
        case .privateBath: String(localized: "Private bath")
        case .viewBath: String(localized: "Bath with a view")
        case .openAirBath: String(localized: "Open-air bath")
        case .sauna: String(localized: "Sauna")
        case .jacuzzi: String(localized: "Jacuzzi")
        case .massage: String(localized: "Massage")
        case .esthetics: String(localized: "Spa treatments")
        case .freeFlowingSpring: String(localized: "Free-flowing natural hot spring")
        case .cloudySpring: String(localized: "Cloudy hot spring")
        case .nonSmokingRoom: String(localized: "Non-smoking room")
        case .inRoomInternet: String(localized: "Internet in the room")
        case .roomWithOpenAirBath: String(localized: "Room with an open-air bath")
        case .highClass: String(localized: "Jalan High Class inn")
        case .pointDiscount: String(localized: "Point discounts accepted")
        case .suiteOrDetachedRoom: String(localized: "Suite or detached room")
        case .bathAndToilet: String(localized: "Private bath and toilet")
        case .tableTennis: String(localized: "Table tennis")
        case .skiRental: String(localized: "Ski rental")
        case .snowboardRental: String(localized: "Snowboard rental")
        case .outdoorPool: String(localized: "Outdoor pool")
        case .indoorPool: String(localized: "Indoor pool")
        case .fitnessGym: String(localized: "Fitness gym")
        case .sportsHall: String(localized: "Gymnasium")
        case .sportsField: String(localized: "Sports ground")
        case .barbecue: String(localized: "Barbecue facilities")
        case .banquetHall: String(localized: "Banquet hall")
        case .withinFiveMinutesOfStation: String(localized: "5 minutes' walk from a station")
        case .withinFiveMinutesOfBeach: String(localized: "5 minutes' walk from a beach")
        case .withinFiveMinutesOfSlope: String(localized: "5 minutes' walk from the slopes")
        case .withinFiveMinutesOfConvenienceStore: String(localized: "5 minutes' walk from a convenience store")
        case .breakfastInRoom: String(localized: "Breakfast in the room")
        case .dinnerInRoom: String(localized: "Dinner in the room")
        case .breakfastInPrivateRoom: String(localized: "Breakfast in a private room")
        case .dinnerInPrivateRoom: String(localized: "Dinner in a private room")
        case .earlyCheckIn: String(localized: "Check-in from 14:00 or earlier")
        case .lateCheckOut: String(localized: "Check-out at 11:00 or later")
        case .freeParking: String(localized: "Free parking")
        case .shuttleService: String(localized: "Shuttle service")
        case .petsAllowed: String(localized: "Pets allowed")
        case .planWithoutMeals: String(localized: "Room-only plans")
        case .breakfastOnlyPlan: String(localized: "Breakfast-only plans")
        case .dinnerOnlyPlan: String(localized: "Dinner-only plans")
        case .twoMealsPlan: String(localized: "Breakfast and dinner plans")
        case .singleRoom: String(localized: "Single rooms")
        case .twinRoom: String(localized: "Twin rooms")
        case .doubleRoom: String(localized: "Double rooms")
        case .tripleRoom: String(localized: "Triple rooms")
        case .fourBedRoom: String(localized: "Four-bed rooms")
        case .japaneseStyleRoom: String(localized: "Japanese-style rooms")
        case .japaneseWesternRoom: String(localized: "Japanese-Western rooms")
        case .childRate: String(localized: "Child rates")
        case .elementarySchoolRate: String(localized: "Primary school rates")
        case .preschoolerBedAndMeal: String(localized: "Preschooler bed and meals")
        case .preschoolerNeither: String(localized: "Preschooler, neither bed nor meals")
        case .preschoolerMealOnly: String(localized: "Preschooler meals only")
        case .preschoolerBedOnly: String(localized: "Preschooler bed only")
        case .creditCard: String(localized: "Credit cards accepted")
        case .cardJCB: "JCB"
        case .cardVisa: "VISA"
        case .cardMastercard: "Mastercard"
        case .cardAmex: "American Express"
        case .cardUC: String(localized: "UC Card")
        case .cardDC: String(localized: "DC Card")
        case .cardNICOS: String(localized: "NICOS Card")
        case .cardDiners: String(localized: "Diners Club")
        case .cardSaison: String(localized: "Saison Card")
        case .cardUFJ: String(localized: "UFJ Card")
        }
    }
}

/// Everything a search can be narrowed by, beyond where to look.
public struct SearchFilters: Sendable, Hashable, Codable {
    public var sortOrder: HotelSortOrder
    public var hotelType: HotelType?
    /// Yen per person per night, as the service reckons it.
    public var minimumRate: Int?
    public var maximumRate: Int?
    public var amenities: Set<Amenity>

    public init(
        sortOrder: HotelSortOrder = .unspecified,
        hotelType: HotelType? = nil,
        minimumRate: Int? = nil,
        maximumRate: Int? = nil,
        amenities: Set<Amenity> = []
    ) {
        self.sortOrder = sortOrder
        self.hotelType = hotelType
        self.minimumRate = minimumRate
        self.maximumRate = maximumRate
        self.amenities = amenities
    }

    /// The rate ladder the 2010 release offered, and the one the UI still shows.
    public static let rateSteps = [
        5_000, 6_000, 7_000, 8_000, 9_000, 10_000, 12_000, 14_000,
        16_000, 18_000, 20_000, 30_000, 40_000, 50_000
    ]

    /// How many narrowing choices are in effect, for the "絞り込み (3)" badge.
    public var activeCount: Int {
        var count = amenities.count
        if sortOrder != .unspecified { count += 1 }
        if hotelType != nil { count += 1 }
        if minimumRate != nil { count += 1 }
        if maximumRate != nil { count += 1 }
        return count
    }

    public var isEmpty: Bool { activeCount == 0 }

    public mutating func reset() {
        self = SearchFilters()
    }

    /// "8,000〜20,000円", or one open end, or `nil` when the budget is not set.
    public var budgetSummary: String? {
        switch (minimumRate, maximumRate) {
        case let (minimum?, maximum?):
            String(localized: "¥\(minimum.groupedDigits)–\(maximum.groupedDigits)")
        case let (minimum?, nil):
            String(localized: "From ¥\(minimum.groupedDigits)")
        case let (nil, maximum?):
            String(localized: "Up to ¥\(maximum.groupedDigits)")
        case (nil, nil): nil
        }
    }

    /// Every chosen amenity, named in full. `nil` when nothing is chosen.
    public var amenitySummary: String? {
        guard !amenities.isEmpty else { return nil }
        return amenities
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.title)
            .joined(separator: String(localized: " · "))
    }
}

extension Int {
    var groupedDigits: String {
        formatted(.number.grouping(.automatic))
    }
}
