import Foundation

/// A bookable stay plan, as returned by the vacancy endpoint.
public struct Plan: Sendable, Hashable, Identifiable {
    /// `PlanCD` alone is not unique — the same plan is offered for several room
    /// types and comes back once per room — so the identity is the pair.
    public struct ID: Sendable, Hashable {
        public let planCode: String
        public let roomCode: String?

        public init(planCode: String, roomCode: String?) {
            self.planCode = planCode
            self.roomCode = roomCode
        }
    }

    public let id: ID
    public let name: String
    public let roomName: String?
    /// `PlanDetailURL` — goes through `JwsRedirect.do` and carries the API key.
    public let detailURL: URL?
    /// `PlanCommonDetailURL` — the plain jalan.net booking page. Preferred for
    /// anything user-facing, because it is a real jalan.net address and so can
    /// be routed through the affiliate redirect.
    public let bookingURL: URL?
    public let pictureURL: URL?
    public let pictureCaption: String?
    public let facilities: [String]
    public let checkIn: String?
    public let checkOut: String?
    public let meal: String?
    /// What `sampleRate` is per, e.g. "大人1名あたり".
    public let rateType: String?
    /// Yen. Called a *sample* rate because it is the plan's representative price,
    /// not a quote for the dates asked about.
    public let sampleRate: Int?
    public let serviceChargeRate: Int?
    public let hotel: Hotel

    public init(
        id: ID,
        name: String,
        roomName: String? = nil,
        detailURL: URL? = nil,
        bookingURL: URL? = nil,
        pictureURL: URL? = nil,
        pictureCaption: String? = nil,
        facilities: [String] = [],
        checkIn: String? = nil,
        checkOut: String? = nil,
        meal: String? = nil,
        rateType: String? = nil,
        sampleRate: Int? = nil,
        serviceChargeRate: Int? = nil,
        hotel: Hotel
    ) {
        self.id = id
        self.name = name
        self.roomName = roomName
        self.detailURL = detailURL
        self.bookingURL = bookingURL
        self.pictureURL = pictureURL
        self.pictureCaption = pictureCaption
        self.facilities = facilities
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.meal = meal
        self.rateType = rateType
        self.sampleRate = sampleRate
        self.serviceChargeRate = serviceChargeRate
        self.hotel = hotel
    }
}

extension Plan {
    init?(element: XMLTreeNode) {
        guard
            let planCode = element.string("PlanCD"),
            let name = element.string("PlanName"),
            let hotelElement = element.child(named: "Hotel"),
            let hotel = Hotel(element: hotelElement)
        else {
            return nil
        }

        self.init(
            id: ID(planCode: planCode, roomCode: element.string("RoomCD")),
            name: name,
            roomName: element.string("RoomName"),
            detailURL: element.url("PlanDetailURL"),
            bookingURL: element.url("PlanCommonDetailURL"),
            pictureURL: element.url("PlanPictureURL"),
            pictureCaption: element.string("PlanPictureCaption"),
            facilities: element.child(named: "Facilities")?
                .children(named: "Facility")
                .compactMap { $0.text.nonEmpty } ?? [],
            checkIn: element.string("PlanCheckIn"),
            checkOut: element.string("PlanCheckOut"),
            meal: element.string("Meal"),
            rateType: element.string("RateType"),
            sampleRate: element.int("SampleRate"),
            serviceChargeRate: element.int("ServiceChargeRate"),
            hotel: hotel
        )
    }
}
