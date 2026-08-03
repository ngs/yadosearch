import Foundation

/// An inn or hotel as the Jalan Web Service describes it.
///
/// The two endpoints return overlapping but unequal subsets of these fields —
/// `HotelSearch` carries access directions and check-in times, the `Hotel` nested
/// inside a `StockSearch` plan carries the rating and the kana reading instead —
/// so everything either one omits is optional here and one decoder serves both.
public struct Hotel: Sendable, Hashable, Identifiable {
    /// Where the inn sits in Jalan's area hierarchy, by name. The codes that go
    /// with these names live in `AreaTree`; the search response only names them.
    public struct Area: Sendable, Hashable {
        public let region: String?
        public let prefecture: String?
        public let largeArea: String?
        public let smallArea: String?

        public init(region: String?, prefecture: String?, largeArea: String?, smallArea: String?) {
            self.region = region
            self.prefecture = prefecture
            self.largeArea = largeArea
            self.smallArea = smallArea
        }
    }

    /// One line of directions, e.g. label "東京駅より", detail "丸ノ内線…徒歩5分".
    public struct Access: Sendable, Hashable, Identifiable {
        public let label: String
        public let detail: String

        public var id: String { label }

        public init(label: String, detail: String) {
            self.label = label
            self.detail = detail
        }
    }

    public let id: String
    public let name: String
    public let nameKana: String?
    public let postCode: String?
    public let address: String
    public let area: Area
    public let type: String?
    /// Opens the inn's page on jalan.net. The URL is keyed to the application
    /// key, so it must be used as given rather than rebuilt from the hotel ID.
    public let detailURL: URL?
    public let catchCopy: String?
    public let caption: String?
    public let pictureURL: URL?
    public let pictureCaption: String?
    public let access: [Access]
    public let checkIn: String?
    public let checkOut: String?
    public let rating: Double?
    public let numberOfRatings: Int?
    /// WGS 84 — already converted from the Tokyo datum the API reports.
    public let coordinate: GeoCoordinate?

    public init(
        id: String,
        name: String,
        nameKana: String? = nil,
        postCode: String? = nil,
        address: String,
        area: Area,
        type: String? = nil,
        detailURL: URL? = nil,
        catchCopy: String? = nil,
        caption: String? = nil,
        pictureURL: URL? = nil,
        pictureCaption: String? = nil,
        access: [Access] = [],
        checkIn: String? = nil,
        checkOut: String? = nil,
        rating: Double? = nil,
        numberOfRatings: Int? = nil,
        coordinate: GeoCoordinate? = nil
    ) {
        self.id = id
        self.name = name
        self.nameKana = nameKana
        self.postCode = postCode
        self.address = address
        self.area = area
        self.type = type
        self.detailURL = detailURL
        self.catchCopy = catchCopy
        self.caption = caption
        self.pictureURL = pictureURL
        self.pictureCaption = pictureCaption
        self.access = access
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.rating = rating
        self.numberOfRatings = numberOfRatings
        self.coordinate = coordinate
    }
}

extension Hotel {
    /// Decodes a `<Hotel>` element from either endpoint.
    ///
    /// Returns `nil` when the element has no ID or no name: those two are what
    /// make the record usable at all, and a row without them is not worth showing.
    init?(element: XMLTreeNode) {
        guard let id = element.string("HotelID"), let name = element.string("HotelName") else {
            return nil
        }
        let areaElement = element.child(named: "Area")
        let coordinate: GeoCoordinate? = {
            guard let x = element.int("X"), let y = element.int("Y") else { return nil }
            return TokyoDatum.toWorld(
                GeoCoordinate(
                    latitude: JalanCoordinateUnit.degrees(fromMilliseconds: y),
                    longitude: JalanCoordinateUnit.degrees(fromMilliseconds: x)
                )
            )
        }()

        self.init(
            id: id,
            name: name,
            nameKana: element.string("HotelNameKana"),
            postCode: element.string("PostCode"),
            address: element.string("HotelAddress") ?? "",
            area: Area(
                region: areaElement?.string("Region"),
                prefecture: areaElement?.string("Prefecture"),
                largeArea: areaElement?.string("LargeArea"),
                smallArea: areaElement?.string("SmallArea")
            ),
            type: element.string("HotelType"),
            detailURL: element.url("HotelDetailURL"),
            catchCopy: element.string("HotelCatchCopy"),
            caption: element.string("HotelCaption"),
            pictureURL: element.url("PictureURL"),
            pictureCaption: element.string("PictureCaption"),
            access: element.children(named: "AccessInformation").compactMap { access in
                guard let label = access.attribute("name"), let detail = access.text.nonEmpty else {
                    return nil
                }
                return Access(label: label, detail: detail)
            },
            checkIn: element.string("CheckInTime"),
            checkOut: element.string("CheckOutTime"),
            rating: element.double("Rating"),
            numberOfRatings: element.int("NumberOfRatings"),
            coordinate: coordinate
        )
    }
}
