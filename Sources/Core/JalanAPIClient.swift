import Foundation

/// A client for the Jalan Web Service (`jws.jalan.net`).
///
/// Three endpoints are in use, and they are the three the service still answers:
///
/// | Purpose | Path |
/// |---|---|
/// | Inn directory search | `APIAdvance/HotelSearch/V1/` |
/// | Stay plans and rates | `APIAdvance/StockSearch/V1/` |
/// | The whole area tree | `APICommon/AreaSearch/V1/` |
///
/// **The scheme is `http` on purpose.** `jws.jalan.net` listens on port 80 only;
/// port 443 is closed, so there is no TLS endpoint to prefer. The app declares a
/// matching App Transport Security exception for that one host.
public struct JalanAPIClient: Sendable {
    public struct Configuration: Sendable, Hashable {
        public var applicationKey: String
        public var host: String

        public init(applicationKey: String, host: String = "jws.jalan.net") {
            self.applicationKey = applicationKey
            self.host = host
        }

        /// The configuration baked into the app at project-generation time.
        ///
        /// direnv exports `TUIST_JALAN_API_KEY` (CI sets it from a repository
        /// secret) and Tuist writes it into `Info.plist`. `nil` means the build
        /// has no key at all, which `YadoSearchEnvironment.init(bundle:)` treats
        /// as fatal — it is a broken build, not something to explain to a user.
        public static func fromBundle(_ bundle: Bundle) -> Configuration? {
            guard
                let key = bundle.object(forInfoDictionaryKey: "JalanAPIKey") as? String,
                !key.isEmpty
            else {
                return nil
            }
            return Configuration(applicationKey: key)
        }
    }

    fileprivate enum Endpoint: String {
        case hotelSearch = "/APIAdvance/HotelSearch/V1/"
        case planSearch = "/APIAdvance/StockSearch/V1/"
        case areaSearch = "/APICommon/AreaSearch/V1/"
    }

    private let configuration: Configuration
    private let session: URLSession

    public init(configuration: Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func searchHotels(_ query: HotelSearchQuery) async throws -> SearchPage<Hotel> {
        let root = try await get(.hotelSearch, query: query.queryItems)
        return page(from: root, elementName: "Hotel", decode: Hotel.init(element:))
    }

    public func searchPlans(_ query: PlanSearchQuery) async throws -> SearchPage<Plan> {
        let root = try await get(.planSearch, query: query.queryItems)
        return page(from: root, elementName: "Plan", decode: Plan.init(element:))
    }

    /// The entire 広域→都道府県→大エリア→小エリア tree, in one request. It is
    /// static enough that callers are expected to fetch it once and hold on to it.
    public func areaTree() async throws -> AreaTree {
        AreaTree(element: try await get(.areaSearch, query: []))
    }
}

private extension JalanAPIClient {
    func url(for endpoint: Endpoint, query: [URLQueryItem]) throws -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = configuration.host
        components.path = endpoint.rawValue
        components.queryItems = [URLQueryItem(name: "key", value: configuration.applicationKey)] + query
        guard let url = components.url else {
            throw JalanAPIError.malformedResponse
        }
        return url
    }

    func get(_ endpoint: Endpoint, query: [URLQueryItem]) async throws -> XMLTreeNode {
        let url = try url(for: endpoint, query: query)
        let data: Data
        do {
            (data, _) = try await session.data(from: url)
        } catch let error as JalanAPIError {
            throw error
        } catch {
            throw JalanAPIError.transport(description: error.localizedDescription)
        }

        let root: XMLTreeNode
        do {
            root = try XMLTree.parse(data)
        } catch {
            throw JalanAPIError.malformedResponse
        }

        // A rejected request answers 400 with an `<Error>` document. Reading the
        // body rather than the status code is what surfaces the service's own
        // explanation, which is the only useful thing about these failures.
        if root.name == "Error" {
            throw JalanAPIError.service(message: root.string("Message") ?? "")
        }
        guard root.name == "Results" else {
            throw JalanAPIError.malformedResponse
        }
        return root
    }

    func page<Element>(
        from root: XMLTreeNode,
        elementName: String,
        decode: (XMLTreeNode) -> Element?
    ) -> SearchPage<Element> {
        let items = root.children(named: elementName).compactMap(decode)
        return SearchPage(
            numberOfResults: root.int("NumberOfResults") ?? items.count,
            displayPerPage: root.int("DisplayPerPage") ?? items.count,
            displayFrom: root.int("DisplayFrom") ?? 1,
            items: items
        )
    }
}
