import Foundation
import Testing
@testable import YadoSearchCore

@Suite("ValueCommerce affiliate links")
struct JalanAffiliateTests {
    private let affiliate = JalanAffiliate.littleApps

    /// The exact conversion the programme specifies.
    @Test("Wraps a jalan.net URL in the referral redirect")
    func wrapsJalanURL() throws {
        let source = try #require(
            URL(string: "https://www.jalan.net/yad384352/?dateUndecided=1&adultNum=2&roomCount=1")
        )

        let wrapped = affiliate.referralURL(for: source)

        #expect(wrapped.absoluteString == """
        https://ck.jp.ap.valuecommerce.com/servlet/referral?sid=2462325&pid=892671706\
        &vc_url=https%3A%2F%2Fwww.jalan.net%2Fyad384352%2F%3FdateUndecided%3D1%26adultNum%3D2%26roomCount%3D1
        """)
    }

    /// Every reserved character has to be encoded, `:` and `/` included, or the
    /// redirect reads the destination as more of its own query.
    @Test("Only unreserved characters survive unencoded")
    func encodesEverythingReserved() throws {
        let source = try #require(URL(string: "https://www.jalan.net/a-b_c.d~e/?x=1&y=2"))

        let wrapped = affiliate.referralURL(for: source)
        let encoded = try #require(
            wrapped.absoluteString.components(separatedBy: "vc_url=").last
        )

        #expect(encoded == "https%3A%2F%2Fwww.jalan.net%2Fa-b_c.d~e%2F%3Fx%3D1%26y%3D2")
        #expect(!encoded.contains(":"))
        #expect(!encoded.contains("/"))
    }

    /// The programme pays for one merchant. Wrapping anything else would break
    /// the link and earn nothing.
    @Test("Leaves non-jalan.net URLs alone")
    func leavesOtherHostsAlone() throws {
        for address in [
            "https://www.rakuten.co.jp/",
            "https://example.com/jalan.net/",
            "https://notjalan.net/yad1/"
        ] {
            let source = try #require(URL(string: address))
            #expect(affiliate.referralURL(for: source) == source)
        }
    }

    @Test("Subdomains of jalan.net are wrapped")
    func wrapsSubdomains() throws {
        let source = try #require(URL(string: "https://www.jalan.net/uw/uwp3200/uww3201init.do?yadNo=300002"))

        #expect(affiliate.referralURL(for: source).host() == "ck.jp.ap.valuecommerce.com")
    }

    @Test("Builds the inn page from the hotel ID")
    func buildsHotelPage() throws {
        let url = try #require(affiliate.hotelPageURL(hotelID: "300002"))

        #expect(url.absoluteString.hasPrefix("https://www.jalan.net/yad300002/?"))
        #expect(url.query()?.contains("dateUndecided=1") == true)
        #expect(url.query()?.contains("adultNum=2") == true)
        #expect(url.query()?.contains("roomCount=1") == true)
        #expect(affiliate.hotelPageURL(hotelID: "") == nil)
    }

    /// The site's query names are camel case and differ from the API's.
    @Test("Carries a chosen date onto the booking page")
    func carriesTheStayOntoThePage() throws {
        let checkIn = try #require(
            StayConditions.calendar.date(from: DateComponents(year: 2_026, month: 9, day: 12))
        )
        let stay = StayConditions(
            checkIn: checkIn,
            nights: 2,
            rooms: 3,
            party: GuestParty(adults: 4)
        )

        let url = try #require(affiliate.hotelPageURL(hotelID: "300002", stay: stay))
        let query = try #require(url.query())

        #expect(query.contains("stayYear=2026"))
        #expect(query.contains("stayMonth=9"))
        #expect(query.contains("stayDay=12"))
        #expect(query.contains("stayCount=2"))
        #expect(query.contains("roomCount=3"))
        #expect(query.contains("adultNum=4"))
        #expect(!query.contains("dateUndecided"))
    }

    @Test("The one-step helper builds and wraps in a single call")
    func buildsAndWraps() throws {
        let url = try #require(affiliate.referralURL(hotelID: "300002"))

        #expect(url.host() == "ck.jp.ap.valuecommerce.com")
        #expect(url.absoluteString.contains("vc_url=https%3A%2F%2Fwww.jalan.net%2Fyad300002%2F"))
    }
}
