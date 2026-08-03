import Foundation
import Testing
@testable import YadoSearchCore

@Suite("Search filters")
struct SearchFiltersTests {
    private func names(_ items: [URLQueryItem]) -> [String] {
        items.map(\.name)
    }

    private func value(_ items: [URLQueryItem], _ name: String) -> String? {
        items.first { $0.name == name }?.value
    }

    /// An unspecified order sends no `order` at all, which is what leaves a
    /// proximity search sorted nearest-first.
    @Test("An empty filter set adds nothing to the query")
    func emptyFiltersAddNothing() {
        let filters = SearchFilters()

        #expect(filters.isEmpty)
        #expect(filters.activeCount == 0)
        #expect(filters.queryItems.isEmpty)
    }

    @Test("Sends the codes the service understands")
    func buildsQueryItems() {
        let filters = SearchFilters(
            sortOrder: .rateAscending,
            hotelType: .japaneseInn,
            minimumRate: 8_000,
            maximumRate: 20_000,
            amenities: [.hotSpring, .nonSmokingRoom]
        )
        let items = filters.queryItems

        #expect(value(items, "order") == "2")
        #expect(value(items, "h_type") == "1")
        #expect(value(items, "min_rate") == "8000")
        #expect(value(items, "max_rate") == "20000")
        #expect(value(items, "onsen") == "1")
        #expect(value(items, "no_smk") == "1")
        #expect(filters.activeCount == 6)
    }

    /// A `Set` has no order, so the query would otherwise differ run to run.
    @Test("The same filters always build the same query")
    func queryIsStable() {
        // Two sets with the same members but built in a different order: a
        // `Set`'s iteration order is not the insertion order, so without the
        // sort these two would disagree.
        let one = SearchFilters(amenities: [.sauna, .hotSpring, .petsAllowed, .freeParking])
        let other = SearchFilters(amenities: [.freeParking, .petsAllowed, .hotSpring, .sauna])

        #expect(names(one.queryItems) == names(other.queryItems))
        #expect(names(one.queryItems) == ["onsen", "parking", "pet", "sauna"])
    }

    @Test("Every amenity belongs to exactly one group, and every group is populated")
    func groupsPartitionTheAmenities() {
        let grouped = Amenity.Group.allCases.flatMap(\.amenities)

        #expect(grouped.count == Amenity.allCases.count)
        #expect(Set(grouped).count == Amenity.allCases.count)
        for group in Amenity.Group.allCases {
            #expect(!group.amenities.isEmpty)
            #expect(!group.title.isEmpty)
        }
    }

    @Test("Every filter option is labelled")
    func everythingIsLabelled() {
        for amenity in Amenity.allCases {
            #expect(!amenity.title.isEmpty)
            #expect(!amenity.rawValue.isEmpty)
        }
        for order in HotelSortOrder.allCases {
            #expect(!order.title.isEmpty)
        }
        for type in HotelType.allCases {
            #expect(!type.title.isEmpty)
        }
    }

    @Test("Resetting clears everything")
    func resets() {
        var filters = SearchFilters(sortOrder: .popularity, amenities: [.hotSpring])

        filters.reset()

        #expect(filters.isEmpty)
    }

    @Test("Adults are always sent, empty child counts are not")
    func partyOmitsZeroes() {
        let plain = GuestParty(adults: 2)
        let withChildren = GuestParty(
            adults: 2,
            elementarySchoolChildren: 1,
            preschoolersWithBedAndMeal: 2
        )

        #expect(names(plain.queryItems) == ["adult_num"])
        #expect(value(withChildren.queryItems, "sc_num") == "1")
        #expect(value(withChildren.queryItems, "lc_num_bed_meal") == "2")
        #expect(value(withChildren.queryItems, "lc_num_meal_only") == nil)
        #expect(withChildren.childCount == 3)
        #expect(withChildren.totalCount == 5)
    }

    @Test("A party of nobody is not possible")
    func clampsTheParty() {
        let party = GuestParty(adults: 0, elementarySchoolChildren: -2)

        #expect(party.adults == 1)
        #expect(party.elementarySchoolChildren == 0)
    }
}
