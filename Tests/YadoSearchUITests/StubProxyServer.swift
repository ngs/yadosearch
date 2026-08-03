import Foundation
import Synchronization
import YadoSearchCore

/// Serves canned proxy responses to a `URLSession`, so the view models can be
/// driven through their real client without a network.
final class StubProxyServer: URLProtocol {
    /// Responses keyed by the `page` parameter, which is what makes paging
    /// testable: page 2 can differ from page 1, and a page can fail.
    struct Script: Sendable {
        var pages: [Int: String]
        var failingPages: Set<Int>
        /// What a failing page answers with. Rakuten's refusals are what this
        /// is for: "Data Not Found" for an empty result, "(status 429)" for its
        /// rate limit — both of which the app has to read rather than repeat.
        var failureBody: String

        init(
            pages: [Int: String],
            failingPages: Set<Int> = [],
            failureBody: String = #"{"error":"テスト用のエラーです。"}"#
        ) {
            self.pages = pages
            self.failingPages = failingPages
            self.failureBody = failureBody
        }
    }

    /// One script per host, not one for the whole process: suites run in
    /// parallel, and a single script means whichever suite installed last
    /// answers everyone's requests.
    private static let scripts = Mutex<[String: Script]>([:])
    static let host = "stub.yadosearch.test"
    private static let domain = ".yadosearch.test"

    static func install(_ newScript: Script, host: String = host) {
        scripts.withLock { $0[host] = newScript }
    }

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProxyServer.self]
        return URLSession(configuration: configuration)
    }

    static var client: YadoSearchAPIClient {
        client(host: host)
    }

    /// A client for one suite's own host, so its script is only ever its own.
    static func client(host: String) -> YadoSearchAPIClient {
        YadoSearchAPIClient(
            configuration: YadoSearchAPIClient.Configuration(
                baseURL: URL(string: "https://\(host)") ?? URL(filePath: "/")
            ),
            session: session
        )
    }

    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasSuffix(domain) ?? false
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let url = request.url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let page = components.queryItems?
            .first { $0.name == "page" }?
            .value
            .flatMap(Int.init) ?? 1

        let current = Self.scripts.withLock { $0[url.host() ?? ""] } ?? Script(pages: [:])
        let body: String
        let status: Int
        if current.failingPages.contains(page) {
            body = current.failureBody
            status = 400
        } else {
            body = current.pages[page] ?? Self.emptyResults
            status = 200
        }

        if let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension StubProxyServer {
    static let emptyResults = #"{"results":[],"totals":{}}"#

    /// A search response with `count` inns, numbered from `firstID`.
    ///
    /// The first inn sits on Tokyo Station and each next one is ~50 m further
    /// east, so the distance labels have something real to measure. These are
    /// WGS 84: the proxy converts Jalan's Tokyo-datum readings before sending.
    static func searchResults(
        total: Int,
        count: Int,
        firstID: Int,
        providers: [Provider] = [.jalan],
        errors: [Provider: String] = [:]
    ) -> String {
        let results = (0 ..< count).map { offset -> String in
            let identifier = firstID + offset
            let longitude = 139.767125 + Double(offset) * 0.00055
            let offers = providers
                .map { #"{"provider":"\#($0.rawValue)","id":"\#(identifier)"}"# }
                .joined(separator: ",")
            return """
            {"name":"テスト旅館\(identifier)",\
            "address":"東京都千代田区丸の内1-\(identifier)",\
            "area":{"region":"首都圏","prefecture":"東京都","large":"東京駅周辺","small":"丸の内"},\
            "kind":"Ryokan","catchCopy":"駅から近い宿\(identifier)",\
            "coordinate":{"latitude":35.681236,"longitude":\(longitude)},\
            "offers":[\(offers)]}
            """
        }
        .joined(separator: ",")

        let totals = providers
            .map { #""\#($0.rawValue)":\#(total)"# }
            .joined(separator: ",")
        let failures = errors
            .map { #""\#($0.key.rawValue)":"\#($0.value)""# }
            .joined(separator: ",")

        return """
        {"results":[\(results)],"totals":{\(totals)}\
        \(failures.isEmpty ? "" : #","errors":{\#(failures)}"#)}
        """
    }
}
