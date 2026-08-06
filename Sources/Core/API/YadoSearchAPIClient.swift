import Foundation

/// A client for the yadosearch-api proxy.
///
/// The proxy is what the app talks to; neither Jalan nor Rakuten is reached
/// directly any more. That is what keeps the upstream credentials off the
/// device, and it is why nothing here needs an application key of its own — the
/// proxy is unauthenticated on purpose, because a key shipped inside an app can
/// be extracted from it and so protects nothing.
///
/// | Purpose | Path |
/// |---|---|
/// | Search, both providers merged | `/v1/hotels` |
/// | One inn, plus its match on the other provider | `/v1/hotels/{provider}/{id}` |
/// | Plans and vacancy for one inn | `/v1/hotels/{provider}/{id}/plans` |
/// | Jalan's area hierarchy | `/v1/areas/jalan` |
/// | Rakuten's area classification | `/v1/areas/rakuten` |
public struct YadoSearchAPIClient: Sendable {
    public struct Configuration: Sendable, Hashable {
        public var baseURL: URL

        public init(baseURL: URL) {
            self.baseURL = baseURL
        }
    }

    private let configuration: Configuration
    private let session: URLSession

    public init(configuration: Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func searchHotels(_ request: HotelSearchRequest) async throws -> SearchResponse {
        try await get("/v1/hotels", query: request.queryItems)
    }

    public func hotel(provider: Provider, id: String) async throws -> HotelDetailResponse {
        try await get("/v1/hotels/\(provider.rawValue)/\(id)")
    }

    /// One inn's plans. Ask for a `stay` with a `checkIn` before asking Rakuten:
    /// it has no undated mode and answers with an error instead.
    public func plans(
        provider: Provider,
        hotelID: String,
        stay: StayRequest,
        page: Int? = nil,
        count: Int? = nil
    ) async throws -> PlanPage {
        var query = stay.queryItems
        if let page { query.append(URLQueryItem(name: "page", value: String(page))) }
        if let count { query.append(URLQueryItem(name: "count", value: String(count))) }
        return try await get("/v1/hotels/\(provider.rawValue)/\(hotelID)/plans", query: query)
    }

    public func jalanAreaTree() async throws -> AreaTree {
        let response: JalanAreaTreeResponse = try await get("/v1/areas/jalan")
        return response.areaTree
    }

    public func rakutenAreaTree() async throws -> RakutenAreaTree {
        let response: RakutenAreaTreeResponse = try await get("/v1/areas/rakuten")
        return response.areaTree
    }

    // MARK: - Transport

    private func get<Value: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Value {
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = query.isEmpty ? nil : query
        guard let url = components?.url else { throw APIError.malformedResponse }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw APIError.transport(description: error.localizedDescription)
        }

        // The proxy reports a refused query as a status code with a JSON body
        // whose message is meant for the caller. Read the body first: it says
        // far more than "400" does.
        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            if let failure = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.service(message: failure.error)
            }
            // Both providers failing turns the whole search into a 502, but the
            // body is still the merged shape, with a per-provider message that
            // the status code hides.
            if let value = try? JSONDecoder().decode(Value.self, from: data) {
                return value
            }
            throw APIError.service(message: "HTTP \(http.statusCode)")
        }

        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw APIError.malformedResponse
        }
    }
}

private struct ErrorResponse: Decodable {
    let error: String
}

/// `/v1/areas/rakuten` is Rakuten's own response, passed through unaltered —
/// the proxy declares no schema for it, on the grounds that the only thing it
/// can promise is what Rakuten said. So this decodes Rakuten's shape: every
/// level is an object behind a single-key wrapper (`{"largeClass": {…}}`), not
/// the array of single-key objects that the rest of `formatVersion=1` uses.
///
/// A level with no children omits the key rather than sending an empty array,
/// which is what makes every array here optional.
struct RakutenAreaTreeResponse: Decodable {
    struct DetailWrapper: Decodable {
        let detailClass: DetailClass
    }

    struct DetailClass: Decodable {
        let detailClassCode: String
        let detailClassName: String
    }

    struct SmallWrapper: Decodable {
        let smallClass: SmallClass
    }

    struct SmallClass: Decodable {
        let smallClassCode: String
        let smallClassName: String
        let detailClasses: [DetailWrapper]?
    }

    struct MiddleWrapper: Decodable {
        let middleClass: MiddleClass
    }

    struct MiddleClass: Decodable {
        let middleClassCode: String
        let middleClassName: String
        let smallClasses: [SmallWrapper]?
    }

    struct LargeWrapper: Decodable {
        let largeClass: LargeClass
    }

    struct LargeClass: Decodable {
        let largeClassCode: String
        let largeClassName: String
        let middleClasses: [MiddleWrapper]?
    }

    struct Classes: Decodable {
        let largeClasses: [LargeWrapper]
    }

    let areaClasses: Classes

    var areaTree: RakutenAreaTree {
        RakutenAreaTree(largeClasses: areaClasses.largeClasses.map { large in
            RakutenAreaTree.LargeClass(
                id: large.largeClass.largeClassCode,
                name: large.largeClass.largeClassName,
                middleClasses: (large.largeClass.middleClasses ?? []).map { middle in
                    RakutenAreaTree.MiddleClass(
                        id: middle.middleClass.middleClassCode,
                        name: middle.middleClass.middleClassName,
                        smallClasses: (middle.middleClass.smallClasses ?? []).map { small in
                            RakutenAreaTree.SmallClass(
                                id: small.smallClass.smallClassCode,
                                name: small.smallClass.smallClassName,
                                detailClasses: (small.smallClass.detailClasses ?? []).map {
                                    RakutenAreaTree.DetailClass(
                                        id: $0.detailClass.detailClassCode,
                                        name: $0.detailClass.detailClassName
                                    )
                                }
                            )
                        }
                    )
                }
            )
        })
    }
}

/// `/v1/areas/jalan` wraps the tree in an `area` object, and spells the levels
/// `code`/`name` where `AreaTree` spells them `id`/`name`.
struct JalanAreaTreeResponse: Decodable {
    struct SmallArea: Decodable {
        let code: String
        let name: String
    }

    struct LargeArea: Decodable {
        let code: String
        let name: String
        let smallAreas: [SmallArea]?
    }

    struct Prefecture: Decodable {
        let code: String
        let name: String
        let largeAreas: [LargeArea]?
    }

    struct Region: Decodable {
        let code: String
        let name: String
        let prefectures: [Prefecture]?
    }

    struct Tree: Decodable {
        let regions: [Region]
    }

    let area: Tree

    var areaTree: AreaTree {
        AreaTree(regions: area.regions.map { region in
            AreaTree.Region(
                id: region.code,
                name: region.name,
                prefectures: (region.prefectures ?? []).map { prefecture in
                    AreaTree.Prefecture(
                        id: prefecture.code,
                        name: prefecture.name,
                        largeAreas: (prefecture.largeAreas ?? []).map { large in
                            AreaTree.LargeArea(
                                id: large.code,
                                name: large.name,
                                smallAreas: (large.smallAreas ?? []).map {
                                    AreaTree.SmallArea(id: $0.code, name: $0.name)
                                }
                            )
                        }
                    )
                }
            )
        })
    }
}
