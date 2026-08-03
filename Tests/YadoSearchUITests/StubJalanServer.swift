import Foundation
import Synchronization
import YadoSearchCore

/// Serves canned Jalan responses to a `URLSession`, so the view models can be
/// driven through their real client without a network.
final class StubJalanServer: URLProtocol {
    /// Responses keyed by the `start` parameter of the request, which is what
    /// makes paging testable: page 2 can differ from page 1, and a page can fail.
    struct Script: Sendable {
        var pages: [Int: String]
        var failingStarts: Set<Int>

        init(pages: [Int: String], failingStarts: Set<Int> = []) {
            self.pages = pages
            self.failingStarts = failingStarts
        }
    }

    private static let script = Mutex<Script>(Script(pages: [:]))

    static func install(_ newScript: Script) {
        script.withLock { $0 = newScript }
    }

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubJalanServer.self]
        return URLSession(configuration: configuration)
    }

    static var client: JalanAPIClient {
        JalanAPIClient(
            configuration: JalanAPIClient.Configuration(applicationKey: "TEST_KEY"),
            session: session
        )
    }

    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "jws.jalan.net"
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
        let start = components.queryItems?
            .first { $0.name == "start" }?
            .value
            .flatMap(Int.init) ?? 1

        let current = Self.script.withLock { $0 }
        let body: String
        let status: Int
        if current.failingStarts.contains(start) {
            body = #"<?xml version="1.0" encoding="UTF-8"?><Error xmlns="jws"><Message>テスト用のエラーです。</Message></Error>"#
            status = 400
        } else {
            body = current.pages[start] ?? Self.emptyResults
            status = 200
        }

        if let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/xml;charset=UTF-8"]
        ) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension StubJalanServer {
    static let emptyResults = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Results xmlns="jws"><NumberOfResults>0</NumberOfResults>\
    <DisplayPerPage>0</DisplayPerPage><DisplayFrom>1</DisplayFrom></Results>
    """

    /// A results document with `count` inns, numbered from `firstID`.
    ///
    /// The first inn sits exactly on Tokyo Station and each next one is ~50 m
    /// further east, so the distance labels have something real to measure. The
    /// coordinates are in the Tokyo datum, because that is what the API sends:
    /// 503_173_204 / 128_440_833 is Tokyo Station's WGS 84 position converted.
    static func hotelResults(total: Int, displayFrom: Int, count: Int, firstID: Int) -> String {
        let hotels = (0..<count).map { offset -> String in
            let identifier = firstID + offset
            let longitude = 503_173_204 + offset * 2_000
            return """
            <Hotel><HotelID>\(identifier)</HotelID><HotelName>テスト旅館\(identifier)</HotelName>\
            <HotelAddress>東京都千代田区丸の内1-\(identifier)</HotelAddress>\
            <Area><Region>首都圏</Region><Prefecture>東京都</Prefecture>\
            <LargeArea>東京駅周辺</LargeArea><SmallArea>丸の内</SmallArea></Area>\
            <HotelType>旅館</HotelType><HotelCatchCopy>駅から近い宿\(identifier)</HotelCatchCopy>\
            <X>\(longitude)</X><Y>128440833</Y></Hotel>
            """
        }
        .joined()

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <Results xmlns="jws"><NumberOfResults>\(total)</NumberOfResults>\
        <DisplayPerPage>\(count)</DisplayPerPage><DisplayFrom>\(displayFrom)</DisplayFrom>\
        \(hotels)</Results>
        """
    }
}
