import Foundation
import Testing
@testable import YadoSearchCore

/// The proxy's own committed examples, decoded through the app's models.
///
/// These files come from `internal/httpapi/testdata/examples/` in the
/// yadosearch-api repository, where a contract test keeps them honest against
/// `openapi.json`. Copying them here means a change to the contract shows up as
/// a failure on this side too.
@Suite("API decoding")
struct APIDecodingTests {
    private func decode<Value: Decodable>(_ type: Value.Type, _ name: String) throws -> Value {
        try JSONDecoder().decode(type, from: try APIFixture.data(name))
    }

    @Test("A keyword search merges both providers into one listing per inn")
    func keywordSearch() throws {
        let response = try decode(SearchResponse.self, "hotels_by_keyword")

        #expect(response.totals[.jalan] == 51)
        #expect(response.totals[.rakuten] == 7)
        #expect(response.errors == nil)

        let listing = try #require(response.results.first)
        #expect(listing.name == "東京ステーションホテル")
        #expect(listing.offers.map(\.provider) == [.jalan, .rakuten])
        // The same inn, numbered differently on each site.
        #expect(listing.offer(from: .jalan)?.id == "387456")
        #expect(listing.offer(from: .rakuten)?.id == "137869")
        // Only Rakuten quoted a price for this one, so that is the lowest.
        #expect(listing.lowestCharge == 26_413)
        #expect(listing.id == "jalan:387456|rakuten:137869")
    }

    @Test("Coordinates arrive in WGS 84, already converted by the proxy")
    func coordinateSearch() throws {
        let response = try decode(SearchResponse.self, "hotels_by_coordinate")
        let listing = try #require(response.results.first)
        let coordinate = try #require(listing.coordinate)

        // Tokyo Station itself is at 35.681236, 139.767125. A Tokyo-datum
        // reading would sit ~400 m away from this.
        #expect(abs(coordinate.latitude - 35.68) < 0.01)
        #expect(abs(coordinate.longitude - 139.76) < 0.01)
        #expect(try #require(listing.distanceMetres) < 1_000)
    }

    @Test("A detail response carries the same inn on the other provider")
    func hotelDetail() throws {
        let response = try decode(HotelDetailResponse.self, "hotel_jalan")

        #expect(response.hotel.provider == .jalan)
        #expect(response.availableProviders == [.jalan, .rakuten])
        #expect(response.profile(for: .jalan)?.id == response.hotel.id)

        let counterpart = try #require(response.profile(for: .rakuten))
        #expect(counterpart.provider == .rakuten)
        #expect(counterpart.id != response.hotel.id)
    }

    @Test("Jalan plans quote a per-person guide rate, Rakuten does not")
    func plans() throws {
        let jalan = try decode(PlanPage.self, "plans_jalan")
        let plan = try #require(jalan.plans.first)
        #expect(plan.provider == .jalan)
        #expect(plan.sampleRate != nil)

        let rakuten = try decode(PlanPage.self, "plans_rakuten")
        #expect(rakuten.plans.first?.provider == .rakuten)
        #expect(rakuten.plans.first?.sampleRate == nil)
    }

    @Test("Paging ends when the page reaches the total")
    func planPaging() throws {
        let page = try decode(PlanPage.self, "plans_jalan")
        #expect(page.from == 1)

        let exhausted = PlanPage(total: page.plans.count, from: 1, plans: page.plans)
        #expect(exhausted.nextPage(after: 1) == nil)
        #expect(PlanPage(total: 100, from: 1, plans: page.plans).nextPage(after: 1) == 2)
        #expect(PlanPage(total: 100, from: 1, plans: []).nextPage(after: 1) == nil)
    }

    @Test("The area tree keeps all four levels")
    func areaTree() throws {
        let response = try decode(JalanAreaTreeResponse.self, "areas_jalan")
        let tree = response.areaTree

        let region = try #require(tree.regions.first)
        let prefecture = try #require(region.prefectures.first)
        let large = try #require(prefecture.largeAreas.first)
        #expect(!region.id.isEmpty)
        #expect(!large.smallAreas.isEmpty)
    }

    @Test("A refused request carries the service's own words")
    func serviceError() throws {
        let failure = try decode(ProxyError.self, "error_rakuten_needs_date")
        #expect(failure.error.contains("checkIn"))
    }
}

/// Mirrors the proxy's `{"error": "…"}` body, which the client turns into
/// `APIError.service`.
struct ProxyError: Decodable {
    let error: String
}

enum APIFixture {
    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures/api"
        ) else {
            throw MissingFixture(name: name)
        }
        return try Data(contentsOf: url)
    }

    struct MissingFixture: Error {
        let name: String
    }
}
