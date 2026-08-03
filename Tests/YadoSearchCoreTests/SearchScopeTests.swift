import Foundation
import Testing
@testable import YadoSearchCore

@Suite("Search scope")
struct SearchScopeTests {
    private func value(_ request: HotelSearchRequest, _ name: String) -> String? {
        request.queryItems.first { $0.name == name }?.value
    }

    /// The proxy searches everything a query can reach when no providers are
    /// named, so `.both` is the absence of the parameter rather than a value.
    @Test("Both providers send no providers parameter")
    func bothSendsNothing() {
        let request = HotelSearchRequest(target: .name("熱海"), scope: .both)

        #expect(request.providers.isEmpty)
        #expect(value(request, "providers") == nil)
    }

    @Test("One provider is named")
    func oneProviderIsNamed() {
        #expect(value(HotelSearchRequest(target: .name("熱海"), scope: .jalan), "providers") == "jalan")
        #expect(value(HotelSearchRequest(target: .name("熱海"), scope: .rakuten), "providers") == "rakuten")
    }

    /// An area target already names its provider by carrying its codes. Sending
    /// `providers` as well would be a second place for the two to disagree.
    @Test("An area search says which site by the codes it carries")
    func areaSearchNeedsNoProviders() {
        let jalan = HotelSearchRequest(target: .area(AreaSelection(prefectureID: "130000")), scope: .jalan)
        #expect(value(jalan, "providers") == nil)
        #expect(value(jalan, "jalanPrefecture") == "130000")

        let rakuten = HotelSearchRequest(
            target: .rakutenArea(RakutenAreaSelection(
                largeClassCode: "japan",
                middleClassCode: "hokkaido",
                smallClassCode: "sapporo",
                detailClassCode: "A"
            ))
        )
        #expect(value(rakuten, "providers") == nil)
        #expect(value(rakuten, "rakutenLargeClass") == "japan")
        #expect(value(rakuten, "rakutenMiddleClass") == "hokkaido")
        #expect(value(rakuten, "rakutenSmallClass") == "sapporo")
        #expect(value(rakuten, "rakutenDetailClass") == "A")
    }

    /// Rakuten answers `specify valid detailClassCode` only where there is one
    /// to give, so a small class without detail classes sends three levels.
    @Test("A small class with no detail classes sends three levels")
    func smallClassWithoutDetail() {
        let request = HotelSearchRequest(
            target: .rakutenArea(RakutenAreaSelection(
                largeClassCode: "japan",
                middleClassCode: "hokkaido",
                smallClassCode: "jozankei"
            ))
        )

        #expect(value(request, "rakutenSmallClass") == "jozankei")
        #expect(value(request, "rakutenDetailClass") == nil)
    }

    /// The target has the last word: an area search cannot reach both sites, so
    /// a scope that says it does is corrected rather than carried.
    @Test("An area target forces the scope")
    func areaTargetForcesScope() {
        let jalan = SavedSearch(
            target: .area(AreaSelection(prefectureID: "130000")),
            scope: .both,
            title: "東京都"
        )
        #expect(jalan.scope == .jalan)

        let rakuten = SavedSearch(
            target: .rakutenArea(RakutenAreaSelection(
                largeClassCode: "japan",
                middleClassCode: "tokyo",
                smallClassCode: "tokyo",
                detailClassCode: "A"
            )),
            scope: .both,
            title: "東京駅・銀座"
        )
        #expect(rakuten.scope == .rakuten)
    }

    /// Every search recorded before there was a choice reached both providers.
    /// Reading a payload with no `scope` as `.both` is what keeps those rows in
    /// the recents list rather than dropping them as undecodable.
    @Test("A stored search from before the choice existed still decodes")
    func decodesPayloadWithoutScope() throws {
        let json = """
        {
          "target": {"name": {"_0": "熱海"}},
          "filters": {"amenities": [], "sortOrder": 0},
          "title": "「熱海」"
        }
        """
        let restored = try JSONDecoder().decode(SavedSearch.self, from: Data(json.utf8))

        #expect(restored.scope == .both)
        #expect(restored.title == "「熱海」")
    }

    /// The scope is a search condition, so two searches that differ only by it
    /// are two rows in the recents list and not one.
    @Test("Identity separates the same search on different sites")
    func identitySeparatesScopes() {
        let jalan = SavedSearch(target: .name("熱海"), scope: .jalan, title: "「熱海」")
        let rakuten = SavedSearch(target: .name("熱海"), scope: .rakuten, title: "「熱海」")
        let both = SavedSearch(target: .name("熱海"), scope: .both, title: "「熱海」")

        #expect(jalan.id != rakuten.id)
        #expect(jalan.id != both.id)
    }

    /// "両方" is what nearly every row would say, so only a narrowed search
    /// spends a line on it.
    @Test("The summary names the site only when it is one of them")
    func summaryNamesTheSite() {
        #expect(SavedSearch(target: .name("熱海"), scope: .both, title: "x").conditionsSummary.isEmpty)
        #expect(SavedSearch(target: .name("熱海"), scope: .jalan, title: "x").conditionsSummary == "じゃらん")
    }
}
