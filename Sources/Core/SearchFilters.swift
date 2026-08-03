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
        case .unspecified: "指定なし"
        case .kana: "50音順"
        case .rateAscending: "参考料金の安い順"
        case .rateDescending: "参考料金の高い順"
        case .popularity: "じゃらんnet人気順"
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
        case .japaneseInn: "旅館"
        case .pensionOrGuesthouse: "ペンション・民宿・ロッジ"
        case .rentalVillaOrCondominium: "貸し別荘・コンドミニアム"
        case .hotel: "ホテル・ビジネスホテル"
        case .publicLodging: "公共の宿"
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
        case bath = "風呂"
        case room = "部屋・宿"
        case facilities = "施設・遊び"
        case location = "立地"
        case service = "サービス"
        case mealsAndRooms = "食事・部屋タイプ"
        case children = "子ども対応"
        case creditCards = "クレジットカード"

        public var id: String { rawValue }
        public var title: String { rawValue }

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
        case .publicBath: "内湯・大浴場"
        case .hotSpring: "温泉"
        case .privateBath: "貸切風呂・貸切露天"
        case .viewBath: "展望風呂"
        case .openAirBath: "露天風呂"
        case .sauna: "サウナ"
        case .jacuzzi: "ジャグジー"
        case .massage: "マッサージ"
        case .esthetics: "エステ設備"
        case .freeFlowingSpring: "天然温泉掛け流し"
        case .cloudySpring: "にごり湯"
        case .nonSmokingRoom: "禁煙ルーム"
        case .inRoomInternet: "部屋でインターネットOK"
        case .roomWithOpenAirBath: "露天風呂付き客室"
        case .highClass: "じゃらんハイクラス掲載の宿"
        case .pointDiscount: "ポイント割引OKの宿"
        case .suiteOrDetachedRoom: "特別室・離れ・スイート"
        case .bathAndToilet: "バス・トイレ付き"
        case .tableTennis: "卓球あり"
        case .skiRental: "貸しスキー"
        case .snowboardRental: "貸しボード"
        case .outdoorPool: "屋外プール"
        case .indoorPool: "屋内プール"
        case .fitnessGym: "フィットネスジム"
        case .sportsHall: "体育館"
        case .sportsField: "グラウンド"
        case .barbecue: "バーベキュー施設"
        case .banquetHall: "宴会場"
        case .withinFiveMinutesOfStation: "駅から徒歩5分"
        case .withinFiveMinutesOfBeach: "ビーチから徒歩5分"
        case .withinFiveMinutesOfSlope: "ゲレンデから徒歩5分"
        case .withinFiveMinutesOfConvenienceStore: "コンビニまで徒歩5分"
        case .breakfastInRoom: "部屋で朝食"
        case .dinnerInRoom: "部屋で夕食"
        case .breakfastInPrivateRoom: "個室で朝食"
        case .dinnerInPrivateRoom: "個室で夕食"
        case .earlyCheckIn: "チェックイン14時以前"
        case .lateCheckOut: "チェックアウト11時以降"
        case .freeParking: "駐車場無料"
        case .shuttleService: "送迎あり"
        case .petsAllowed: "ペットOK"
        case .planWithoutMeals: "食事なしプランあり"
        case .breakfastOnlyPlan: "朝食のみプランあり"
        case .dinnerOnlyPlan: "夕食のみプランあり"
        case .twoMealsPlan: "朝夕食付プランあり"
        case .singleRoom: "シングルルームあり"
        case .twinRoom: "ツインルームあり"
        case .doubleRoom: "ダブルルームあり"
        case .tripleRoom: "トリプルルームあり"
        case .fourBedRoom: "4ベッドルームあり"
        case .japaneseStyleRoom: "和室あり"
        case .japaneseWesternRoom: "和洋室あり"
        case .childRate: "子供料金設定あり"
        case .elementarySchoolRate: "小学生料金設定あり"
        case .preschoolerBedAndMeal: "幼児向けに布団・食事ともにあり"
        case .preschoolerNeither: "幼児向けに布団・食事ともになし"
        case .preschoolerMealOnly: "幼児向けに食事のみあり"
        case .preschoolerBedOnly: "幼児向けに布団のみあり"
        case .creditCard: "クレジットカード利用可"
        case .cardJCB: "JCB"
        case .cardVisa: "VISA"
        case .cardMastercard: "Mastercard"
        case .cardAmex: "American Express"
        case .cardUC: "UCカード"
        case .cardDC: "DCカード"
        case .cardNICOS: "NICOSカード"
        case .cardDiners: "ダイナースクラブ"
        case .cardSaison: "セゾンカード"
        case .cardUFJ: "UFJカード"
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
        case let (minimum?, maximum?): "\(minimum.groupedDigits)〜\(maximum.groupedDigits)円"
        case let (minimum?, nil): "\(minimum.groupedDigits)円〜"
        case let (nil, maximum?): "〜\(maximum.groupedDigits)円"
        case (nil, nil): nil
        }
    }

    /// Every chosen amenity, named in full. `nil` when nothing is chosen.
    public var amenitySummary: String? {
        guard !amenities.isEmpty else { return nil }
        return amenities
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.title)
            .joined(separator: "・")
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if sortOrder != .unspecified {
            items.append(URLQueryItem(name: "order", value: String(sortOrder.rawValue)))
        }
        if let hotelType {
            items.append(URLQueryItem(name: "h_type", value: String(hotelType.rawValue)))
        }
        if let minimumRate {
            items.append(URLQueryItem(name: "min_rate", value: String(minimumRate)))
        }
        if let maximumRate {
            items.append(URLQueryItem(name: "max_rate", value: String(maximumRate)))
        }
        // Sorted so the same filter set always builds the same URL, which keeps
        // the request cacheable and the tests stable.
        for amenity in amenities.sorted(by: { $0.rawValue < $1.rawValue }) {
            items.append(URLQueryItem(name: amenity.rawValue, value: "1"))
        }
        return items
    }
}

extension Int {
    var groupedDigits: String {
        formatted(.number.grouping(.automatic))
    }
}
