import Foundation
import Testing
@testable import YadoSearchCore

@Suite("Hotel search response")
struct HotelParsingTests {
    private func root() throws -> XMLTreeNode {
        try XMLTree.parse(Fixture.data("hotel-search"))
    }

    @Test("Reads the paging counters")
    func readsPagingCounters() throws {
        let root = try root()

        #expect(root.name == "Results")
        #expect((root.int("NumberOfResults") ?? 0) > 100)
        #expect(root.int("DisplayPerPage") == 3)
        #expect(root.int("DisplayFrom") == 1)
        #expect(root.children(named: "Hotel").count == 3)
    }

    @Test("Decodes an inn")
    func decodesAnInn() throws {
        let hotels = try root().children(named: "Hotel").compactMap(Hotel.init(element:))
        let hotel = try #require(hotels.first)

        #expect(!hotel.id.isEmpty)
        #expect(!hotel.name.isEmpty)
        #expect(hotel.address.hasPrefix("東京都"))
        #expect(hotel.area.prefecture == "東京都")
        #expect(hotel.area.region != nil)
        #expect(hotel.pictureURL?.scheme == "https")
        #expect(hotel.detailURL != nil)
    }

    @Test("Access directions keep their labels")
    func decodesAccessDirections() throws {
        let hotels = try root().children(named: "Hotel").compactMap(Hotel.init(element:))
        let withAccess = try #require(hotels.first { !$0.access.isEmpty })

        #expect(withAccess.access.allSatisfy { !$0.label.isEmpty && !$0.detail.isEmpty })
    }

    /// Every inn in the fixture is in Tokyo, so its converted coordinate has to
    /// land inside the metropolis rather than 400 m outside whatever it names.
    @Test("Coordinates come out in WGS 84")
    func convertsCoordinates() throws {
        let hotels = try root().children(named: "Hotel").compactMap(Hotel.init(element:))
        let coordinates = hotels.compactMap(\.coordinate)

        #expect(coordinates.count == hotels.count)
        for coordinate in coordinates {
            #expect((35.4...35.9).contains(coordinate.latitude))
            #expect((139.3...139.95).contains(coordinate.longitude))
        }
    }

    @Test("An empty element counts as absent")
    func treatsEmptyElementsAsAbsent() throws {
        // `<WifiHikariStation></WifiHikariStation>` is how the API says "no".
        let hotel = try #require(root().children(named: "Hotel").first)

        #expect(hotel.string("WifiHikariStation") == nil)
    }

    @Test("An inn without an ID or a name is dropped")
    func dropsUnusableRecords() {
        let element = XMLTreeNode(
            name: "Hotel",
            children: [XMLTreeNode(name: "HotelAddress", text: "東京都千代田区")]
        )

        #expect(Hotel(element: element) == nil)
    }
}
