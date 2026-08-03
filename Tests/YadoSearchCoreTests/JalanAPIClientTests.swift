import Foundation
import Synchronization
import Testing
@testable import YadoSearchCore

/// Answers requests from the captured fixtures instead of the network.
///
/// The routing table is written once, before any test runs, and only read after
/// that — which is what makes it safe under Swift Testing's parallel execution.
final class StubURLProtocol: URLProtocol {
    struct Stub: Sendable {
        let statusCode: Int
        let body: Data
    }

    /// Path → response, plus the query of the last request to reach that path,
    /// so request building can be asserted on.
    private static let routes = Mutex<[String: Stub]>([:])
    private static let lastQueries = Mutex<[String: String]>([:])

    static func register(path: String, statusCode: Int = 200, body: Data) {
        routes.withLock { $0[path] = Stub(statusCode: statusCode, body: body) }
    }

    static func lastQuery(forPath path: String) -> String? {
        lastQueries.withLock { $0[path] }
    }

    static func queryItems(forPath path: String) -> [String: String] {
        guard let query = lastQuery(forPath: path) else { return [:] }
        return query.split(separator: "&").reduce(into: [:]) { result, pair in
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { return }
            result[String(parts[0])] = String(parts[1]).removingPercentEncoding ?? String(parts[1])
        }
    }

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "jws.jalan.net"
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        Self.lastQueries.withLock { $0[components.path] = components.query ?? "" }

        guard let stub = Self.routes.withLock({ $0[components.path] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/xml;charset=UTF-8"]
        )
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Serialized because the stub records the last request per path, and several
/// tests here assert on the request they just made to the same path.
@Suite("Jalan API client", .serialized)
struct JalanAPIClientTests {
    private static let ready: Bool = {
        for (path, fixture) in [
            ("/APIAdvance/HotelSearch/V1/", "hotel-search"),
            ("/APIAdvance/StockSearch/V1/", "plan-search"),
            ("/APICommon/AreaSearch/V1/", "area-tree")
        ] {
            StubURLProtocol.register(path: path, body: (try? Fixture.data(fixture)) ?? Data())
        }
        StubURLProtocol.register(
            path: "/APIAdvance/Rejected/V1/",
            statusCode: 400,
            body: (try? Fixture.data("error")) ?? Data()
        )
        return true
    }()

    private func makeClient(key: String = "TEST_KEY") -> JalanAPIClient {
        _ = Self.ready
        return JalanAPIClient(
            configuration: JalanAPIClient.Configuration(applicationKey: key),
            session: StubURLProtocol.session
        )
    }

    @Test("Searches inns by area")
    func searchesByArea() async throws {
        let page = try await makeClient().searchHotels(
            HotelSearchQuery(target: .area(AreaSelection(prefectureID: "130000")), count: 3)
        )

        #expect(page.items.count == 3)
        #expect(page.displayFrom == 1)
        #expect(page.nextStart == 4)

        let query = StubURLProtocol.queryItems(forPath: "/APIAdvance/HotelSearch/V1/")
        #expect(query["key"] == "TEST_KEY")
        #expect(query["pref"] == "130000")
        #expect(query["count"] == "3")
    }

    /// The request has to carry Tokyo-datum coordinates, because that is the
    /// datum the service both reads and answers in. A WGS 84 position passed
    /// through unconverted lands ~400 m away.
    @Test("Converts the search centre into the Tokyo datum")
    func convertsSearchCentre() async throws {
        let tokyoStation = GeoCoordinate(latitude: 35.681236, longitude: 139.767125)
        _ = try await makeClient().searchHotels(
            HotelSearchQuery(target: .around(tokyoStation, radius: .aboutTwoAndAHalfKilometres))
        )

        let query = StubURLProtocol.queryItems(forPath: "/APIAdvance/HotelSearch/V1/")
        let longitude = try #require(query["x"].flatMap(Int.init))
        let latitude = try #require(query["y"].flatMap(Int.init))
        let sent = GeoCoordinate(
            latitude: JalanCoordinateUnit.degrees(fromMilliseconds: latitude),
            longitude: JalanCoordinateUnit.degrees(fromMilliseconds: longitude)
        )

        #expect(query["range"] == "2")
        #expect(abs(TokyoDatum.toWorld(sent).latitude - tokyoStation.latitude) < 0.00001)
        #expect(abs(TokyoDatum.toWorld(sent).longitude - tokyoStation.longitude) < 0.00001)
    }

    @Test("Sends the stay conditions with a plan search")
    func sendsStayConditions() async throws {
        let checkIn = try #require(
            StayConditions.calendar.date(from: DateComponents(year: 2_026, month: 9, day: 12))
        )
        let page = try await makeClient().searchPlans(
            PlanSearchQuery(
                target: .hotel(id: "300002"),
                stay: StayConditions(
                    checkIn: checkIn,
                    nights: 2,
                    rooms: 2,
                    party: GuestParty(adults: 3, elementarySchoolChildren: 1)
                )
            )
        )

        #expect(!page.items.isEmpty)

        let query = StubURLProtocol.queryItems(forPath: "/APIAdvance/StockSearch/V1/")
        #expect(query["h_id"] == "300002")
        #expect(query["stay_year"] == "2026")
        #expect(query["stay_month"] == "9")
        #expect(query["stay_day"] == "12")
        #expect(query["stay_count"] == "2")
        #expect(query["adult_num"] == "3")
        #expect(query["sc_num"] == "1")
        #expect(query["room_count"] == "2")
    }

    @Test("Filters and the party ride along with a hotel search")
    func sendsFiltersAndParty() async throws {
        _ = try await makeClient().searchHotels(
            HotelSearchQuery(
                target: .area(AreaSelection(prefectureID: "130000")),
                filters: SearchFilters(
                    sortOrder: .popularity,
                    hotelType: .hotel,
                    maximumRate: 12_000,
                    amenities: [.hotSpring, .withinFiveMinutesOfStation]
                ),
                party: GuestParty(adults: 3)
            )
        )

        let query = StubURLProtocol.queryItems(forPath: "/APIAdvance/HotelSearch/V1/")
        #expect(query["order"] == "4")
        #expect(query["h_type"] == "4")
        #expect(query["max_rate"] == "12000")
        #expect(query["onsen"] == "1")
        #expect(query["5_station"] == "1")
        #expect(query["adult_num"] == "3")
        #expect(query["min_rate"] == nil)
    }

    @Test("Fetches the area tree")
    func fetchesAreaTree() async throws {
        let tree = try await makeClient().areaTree()

        #expect(tree.regions.count == 12)
    }

    @Test("A build without a key never reaches the network")
    func refusesWithoutKey() async {
        await #expect(throws: JalanAPIError.missingApplicationKey) {
            try await makeClient(key: "").searchHotels(
                HotelSearchQuery(target: .area(AreaSelection(prefectureID: "130000")))
            )
        }
    }

    /// A rejection is a 400 whose body explains itself; the message is what the
    /// user needs to see, so it must survive rather than becoming "HTTP 400".
    @Test("Surfaces the service's own error message")
    func surfacesServiceErrors() async throws {
        let body = try Fixture.data("error")
        let root = try XMLTree.parse(body)
        let message = try #require(root.string("Message"))

        #expect(root.name == "Error")
        #expect(message.contains("指定してください"))
    }

    @Test("A short final page ends the walk")
    func detectsLastPage() {
        let full = SearchPage(numberOfResults: 5, displayPerPage: 3, displayFrom: 1, items: [1, 2, 3])
        let last = SearchPage(numberOfResults: 5, displayPerPage: 3, displayFrom: 4, items: [4, 5])
        let empty = SearchPage(numberOfResults: 0, displayPerPage: 3, displayFrom: 1, items: [Int]())

        #expect(full.nextStart == 4)
        #expect(last.nextStart == nil)
        #expect(empty.nextStart == nil)
    }
}
