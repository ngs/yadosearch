import Foundation
import Testing
@testable import YadoSearchCore

@Suite("Saved searches")
struct SavedSearchTests {
    private func search(
        target: SearchTarget = .area(AreaSelection(prefectureID: "130000")),
        filters: SearchFilters = SearchFilters(),
        party: GuestParty? = nil,
        title: String = "東京都"
    ) -> SavedSearch {
        SavedSearch(target: target, filters: filters, party: party, title: title)
    }

    /// Identity is the conditions, so re-running a search moves one row rather
    /// than adding a second that looks the same.
    @Test("Identity ignores the title")
    func identityIgnoresTitle() {
        let one = search(title: "東京都")
        let renamed = search(title: "東京都（再検索）")

        #expect(one.id == renamed.id)
    }

    @Test("Different conditions are different searches")
    func differentConditionsDiffer() {
        let plain = search()
        let filtered = search(filters: SearchFilters(hotelType: .japaneseInn))
        let elsewhere = search(target: .area(AreaSelection(prefectureID: "010000")))
        let withParty = search(party: GuestParty(adults: 4))

        #expect(Set([plain.id, filtered.id, elsewhere.id, withParty.id]).count == 4)
    }

    /// A `Set` of amenities has no inherent order, so the fingerprint would
    /// otherwise differ between two identical searches.
    @Test("The fingerprint is stable across equal filter sets")
    func fingerprintIsStable() {
        let one = search(filters: SearchFilters(amenities: [.hotSpring, .sauna]))
        let other = search(filters: SearchFilters(amenities: [.sauna, .hotSpring]))

        #expect(one.id == other.id)
    }

    @Test("Round-trips through JSON, including a proximity target")
    func roundTripsThroughJSON() throws {
        let original = search(
            target: .around(
                GeoCoordinate(latitude: 35.681236, longitude: 139.767125),
                radius: .aboutFiveKilometres
            ),
            filters: SearchFilters(sortOrder: .popularity, maximumRate: 20_000, amenities: [.hotSpring]),
            party: GuestParty(adults: 2, elementarySchoolChildren: 1),
            title: "東京都千代田区から約5km"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SavedSearch.self, from: data)

        #expect(decoded == original)
        #expect(decoded.id == original.id)
    }

    @Test("Every target shape survives the round trip")
    func roundTripsEveryTarget() throws {
        let targets: [SearchTarget] = [
            .name("星野"),
            .area(AreaSelection(regionID: "15", prefectureID: "130000", largeAreaID: "136700")),
            .around(GeoCoordinate(latitude: 35.0, longitude: 139.0), radius: .aboutOneKilometre),
            .hotel(id: "300002")
        ]

        for target in targets {
            let data = try JSONEncoder().encode(target)
            #expect(try JSONDecoder().decode(SearchTarget.self, from: data) == target)
        }
    }

    @Test("Summarises what was narrowed")
    func summarisesConditions() {
        let none = search()
        let some = search(
            filters: SearchFilters(
                sortOrder: .rateAscending,
                hotelType: .japaneseInn,
                minimumRate: 8_000,
                maximumRate: 20_000,
                amenities: [.hotSpring]
            )
        )

        #expect(none.conditionsSummary.isEmpty)
        #expect(some.conditionsSummary.contains("参考料金の安い順"))
        #expect(some.conditionsSummary.contains("旅館"))
        #expect(some.conditionsSummary.contains("8,000〜20,000円"))
        #expect(some.conditionsSummary.contains("温泉"))
    }

    /// A long amenity list would otherwise run off the row.
    @Test("A long amenity list is abbreviated")
    func abbreviatesLongAmenityLists() {
        let summary = search(
            filters: SearchFilters(
                amenities: [.hotSpring, .sauna, .petsAllowed, .freeParking, .nonSmokingRoom]
            )
        ).conditionsSummary

        #expect(summary.contains("ほか2件"))
    }

    @Test("An open-ended budget reads as open-ended")
    func summarisesOpenEndedBudgets() {
        #expect(search(filters: SearchFilters(minimumRate: 10_000)).conditionsSummary == "10,000円〜")
        #expect(search(filters: SearchFilters(maximumRate: 10_000)).conditionsSummary == "〜10,000円")
    }
}
