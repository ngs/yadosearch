import Foundation
import Testing
import YadoSearchCore
@testable import YadoSearchUI

/// The plan search against 楽天トラベル, which answers unlike じゃらん in two
/// ways that both used to reach the screen as raw upstream text.
@MainActor
@Suite("Rakuten plan search", .serialized)
struct RakutenPlanSearchTests {
    /// Its own host, so a suite running alongside cannot answer these requests.
    private static let host = "rakuten-plans.yadosearch.test"

    private static let onePlan = """
    {"total":1,"from":1,"plans":[{"provider":"rakuten","hotelId":"137869","id":"1",
    "name":"Plan","roomName":"Room","detailUrl":"https://example.com/"}]}
    """

    private func rakutenListing() throws -> HotelListing {
        let json = #"{"name":"Inn","offers":[{"provider":"rakuten","id":"137869"}]}"#
        return try JSONDecoder().decode(HotelListing.self, from: Data(json.utf8))
    }

    private func model() throws -> HotelDetailViewModel {
        try HotelDetailViewModel(
            provider: .rakuten,
            listing: rakutenListing(),
            client: StubProxyServer.client(host: Self.host)
        )
    }

    /// The reload is a task the setter starts, so a test that changes the stay
    /// has to give it a turn before reading the phase back.
    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    @Test("Choosing a check-in date replaces the prompt with the plans")
    func datePickedLoadsPlans() async throws {
        StubProxyServer.install(.init(pages: [0: Self.onePlan, 1: Self.onePlan]), host: Self.host)
        let model = try model()
        await model.load()
        #expect(model.plansPhase == .needsCheckIn)

        model.stay.checkIn = Date(timeIntervalSince1970: 1_800_000_000)
        try await settle()

        #expect(model.plansPhase == .loaded, "phase was \(model.plansPhase)")
        #expect(model.plans.count == 1)
    }

    @Test("Nothing on offer reads as an empty result, not as a failure")
    func dataNotFoundIsEmpty() async throws {
        // What 楽天 answers when no plan matches the party or the dates: a
        // failure whose text is "Data Not Found", with a 502 behind it.
        // じゃらん answers 200 and `"total": 0` for the same question.
        StubProxyServer.install(.init(
            pages: [:],
            failingPages: [0, 1],
            failureBody: #"{"error":"Data Not Found"}"#
        ), host: Self.host)
        let model = try model()
        model.stay.checkIn = Date(timeIntervalSince1970: 1_800_000_000)
        await model.loadPlans()

        #expect(model.plansPhase == .loaded, "phase was \(model.plansPhase)")
        #expect(model.plans.isEmpty)
    }

    @Test("The rate limit is said in words, not in a status code")
    func rateLimitIsExplained() async throws {
        StubProxyServer.install(.init(
            pages: [:],
            failingPages: [0, 1],
            failureBody: #"{"error":"rakuten:  (status 429)"}"#
        ), host: Self.host)
        let model = try model()
        model.stay.checkIn = Date(timeIntervalSince1970: 1_800_000_000)
        await model.loadPlans()

        guard case let .failed(message) = model.plansPhase else {
            Issue.record("expected a failure, got \(model.plansPhase)")
            return
        }
        #expect(!message.contains("429"))
        #expect(message.localizedCaseInsensitiveContains("busy"))
    }
}
