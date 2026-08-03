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
        case .unspecified: String(localized: "指定なし")
        case .kana: String(localized: "50音順")
        case .rateAscending: String(localized: "参考料金の安い順")
        case .rateDescending: String(localized: "参考料金の高い順")
        case .popularity: String(localized: "じゃらんnet人気順")
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
        case .japaneseInn: String(localized: "旅館")
        case .pensionOrGuesthouse: String(localized: "ペンション・民宿・ロッジ")
        case .rentalVillaOrCondominium: String(localized: "貸し別荘・コンドミニアム")
        case .hotel: String(localized: "ホテル・ビジネスホテル")
        case .publicLodging: String(localized: "公共の宿")
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
        case .publicBath: String(localized: "内湯・大浴場")
        case .hotSpring: String(localized: "温泉")
        case .privateBath: String(localized: "貸切風呂・貸切露天")
        case .viewBath: String(localized: "展望風呂")
        case .openAirBath: String(localized: "露天風呂")
        case .sauna: String(localized: "サウナ")
        case .jacuzzi: String(localized: "ジャグジー")
        case .massage: String(localized: "マッサージ")
        case .esthetics: String(localized: "エステ設備")
        case .freeFlowingSpring: String(localized: "天然温泉掛け流し")
        case .cloudySpring: String(localized: "にごり湯")
        case .nonSmokingRoom: String(localized: "禁煙ルーム")
        case .inRoomInternet: String(localized: "部屋でインターネットOK")
        case .roomWithOpenAirBath: String(localized: "露天風呂付き客室")
        case .highClass: String(localized: "じゃらんハイクラス掲載の宿")
        case .pointDiscount: String(localized: "ポイント割引OKの宿")
        case .suiteOrDetachedRoom: String(localized: "特別室・離れ・スイート")
        case .bathAndToilet: String(localized: "バス・トイレ付き")
        case .tableTennis: String(localized: "卓球あり")
        case .skiRental: String(localized: "貸しスキー")
        case .snowboardRental: String(localized: "貸しボード")
        case .outdoorPool: String(localized: "屋外プール")
        case .indoorPool: String(localized: "屋内プール")
        case .fitnessGym: String(localized: "フィットネスジム")
        case .sportsHall: String(localized: "体育館")
        case .sportsField: String(localized: "グラウンド")
        case .barbecue: String(localized: "バーベキュー施設")
        case .banquetHall: String(localized: "宴会場")
        case .withinFiveMinutesOfStation: String(localized: "駅から徒歩5分")
        case .withinFiveMinutesOfBeach: String(localized: "ビーチから徒歩5分")
        case .withinFiveMinutesOfSlope: String(localized: "ゲレンデから徒歩5分")
        case .withinFiveMinutesOfConvenienceStore: String(localized: "コンビニまで徒歩5分")
        case .breakfastInRoom: String(localized: "部屋で朝食")
        case .dinnerInRoom: String(localized: "部屋で夕食")
        case .breakfastInPrivateRoom: String(localized: "個室で朝食")
        case .dinnerInPrivateRoom: String(localized: "個室で夕食")
        case .earlyCheckIn: String(localized: "チェックイン14時以前")
        case .lateCheckOut: String(localized: "チェックアウト11時以降")
        case .freeParking: String(localized: "駐車場無料")
        case .shuttleService: String(localized: "送迎あり")
        case .petsAllowed: String(localized: "ペットOK")
        case .planWithoutMeals: String(localized: "食事なしプランあり")
        case .breakfastOnlyPlan: String(localized: "朝食のみプランあり")
        case .dinnerOnlyPlan: String(localized: "夕食のみプランあり")
        case .twoMealsPlan: String(localized: "朝夕食付プランあり")
        case .singleRoom: String(localized: "シングルルームあり")
        case .twinRoom: String(localized: "ツインルームあり")
        case .doubleRoom: String(localized: "ダブルルームあり")
        case .tripleRoom: String(localized: "トリプルルームあり")
        case .fourBedRoom: String(localized: "4ベッドルームあり")
        case .japaneseStyleRoom: String(localized: "和室あり")
        case .japaneseWesternRoom: String(localized: "和洋室あり")
        case .childRate: String(localized: "子供料金設定あり")
        case .elementarySchoolRate: String(localized: "小学生料金設定あり")
        case .preschoolerBedAndMeal: String(localized: "幼児向けに布団・食事ともにあり")
        case .preschoolerNeither: String(localized: "幼児向けに布団・食事ともになし")
        case .preschoolerMealOnly: String(localized: "幼児向けに食事のみあり")
        case .preschoolerBedOnly: String(localized: "幼児向けに布団のみあり")
        case .creditCard: String(localized: "クレジットカード利用可")
        case .cardJCB: "JCB"
        case .cardVisa: "VISA"
        case .cardMastercard: "Mastercard"
        case .cardAmex: "American Express"
        case .cardUC: String(localized: "UCカード")
        case .cardDC: String(localized: "DCカード")
        case .cardNICOS: String(localized: "NICOSカード")
        case .cardDiners: String(localized: "ダイナースクラブ")
        case .cardSaison: String(localized: "セゾンカード")
        case .cardUFJ: String(localized: "UFJカード")
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
            String(localized: "\(minimum.groupedDigits)〜\(maximum.groupedDigits)円")
        case let (minimum?, nil):
            String(localized: "\(minimum.groupedDigits)円〜")
        case let (nil, maximum?):
            String(localized: "〜\(maximum.groupedDigits)円")
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
}

extension Int {
    var groupedDigits: String {
        formatted(.number.grouping(.automatic))
    }
}
