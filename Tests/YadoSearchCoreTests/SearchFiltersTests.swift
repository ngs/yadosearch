import Foundation
import Testing
@testable import YadoSearchCore

@Suite("Search filters")
struct SearchFiltersTests {
    /// The `amenities` parameter for one filter set: a sorted, comma-separated
    /// list, which is what makes the same filters build the same query.
    private func amenityList(_ filters: SearchFilters) -> String? {
        value(HotelSearchRequest(target: .name("宿"), filters: filters).queryItems, "amenities")
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
        #expect(HotelSearchRequest(target: .name("宿"), filters: filters).amenities.isEmpty)
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
        let items = HotelSearchRequest(target: .name("宿"), filters: filters).queryItems

        #expect(value(items, "order") == "2")
        #expect(value(items, "hotelType") == "1")
        #expect(value(items, "minRate") == "8000")
        #expect(value(items, "maxRate") == "20000")
        // One comma-separated parameter now, rather than a flag each.
        #expect(value(items, "amenities") == "no_smk,onsen")
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

        #expect(amenityList(one) == amenityList(other))
        #expect(amenityList(one) == "onsen,parking,pet,sauna")
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

    /// These drive the rows of the 検索条件 section, which lists only what is
    /// actually set.
    @Test("Summarises the budget, both ends and one")
    func summarisesBudget() {
        #expect(SearchFilters().budgetSummary == nil)
        #expect(SearchFilters(minimumRate: 8_000, maximumRate: 20_000).budgetSummary == "8,000〜20,000円")
        #expect(SearchFilters(minimumRate: 10_000).budgetSummary == "10,000円〜")
        #expect(SearchFilters(maximumRate: 10_000).budgetSummary == "〜10,000円")
    }

    /// Every chosen amenity is named — the list is never abbreviated.
    @Test("Summarises the amenities in full")
    func summarisesAmenities() throws {
        #expect(SearchFilters().amenitySummary == nil)
        #expect(SearchFilters(amenities: [.hotSpring]).amenitySummary == "温泉")

        let many = SearchFilters(
            amenities: [.hotSpring, .sauna, .petsAllowed, .freeParking, .nonSmokingRoom]
        )
        let summary = try #require(many.amenitySummary)

        #expect(summary.split(separator: "・").count == 5)
        #expect(!summary.contains("ほか"))
        for amenity in many.amenities {
            #expect(summary.contains(amenity.title))
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

        let plainItems = HotelSearchRequest(target: .name("宿"), party: plain).queryItems
        let items = HotelSearchRequest(target: .name("宿"), party: withChildren).queryItems

        #expect(value(plainItems, "adults") == "2")
        #expect(value(plainItems, "schoolChildren") == nil)
        #expect(value(items, "schoolChildren") == "1")
        #expect(value(items, "preschoolersWithBedAndMeal") == "2")
        #expect(value(items, "preschoolersWithMealOnly") == nil)
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
