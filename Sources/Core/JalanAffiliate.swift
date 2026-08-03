import Foundation

/// Rewrites jalan.net links so bookings are credited to the ValueCommerce
/// affiliate account, and builds the inn pages to link to.
///
/// The redirect takes the destination as one percent-encoded query value:
///
/// ```
/// https://ck.jp.ap.valuecommerce.com/servlet/referral
///   ?sid=2462325&pid=892671706
///   &vc_url=https%3A%2F%2Fwww.jalan.net%2Fyad384352%2F%3FdateUndecided%3D1…
/// ```
///
/// The 2010 release did the same thing (`kVCURLFormat` in its `AppConfig.h`);
/// only the program ID has moved on since.
public struct JalanAffiliate: Sendable, Hashable {
    /// ValueCommerce site ID.
    public let siteID: String
    /// ValueCommerce program ID, which identifies the merchant (Jalan).
    public let programID: String

    public init(siteID: String, programID: String) {
        self.siteID = siteID
        self.programID = programID
    }

    public static let littleApps = JalanAffiliate(siteID: "2462325", programID: "892671706")

    /// Wraps a destination in the referral redirect.
    ///
    /// Returns the URL unchanged when it is not a jalan.net address: the
    /// program only pays for that merchant, and sending anything else through
    /// the redirect would break the link rather than earn anything.
    public func referralURL(for destination: URL) -> URL {
        guard destination.isJalanAddress, let encoded = destination.fullyPercentEncoded else {
            return destination
        }
        // Built as a string, not with `URLComponents`, because `vc_url` is
        // already percent-encoded: handing it to `queryItems` would encode the
        // percent signs again and the redirect would land on a mangled URL.
        let url = URL(
            string: "https://ck.jp.ap.valuecommerce.com/servlet/referral"
                + "?sid=\(siteID)&pid=\(programID)&vc_url=\(encoded)"
        )
        return url ?? destination
    }

    /// The public page for an inn, with the stay carried over so the booking
    /// form opens already filled in.
    ///
    /// `https://www.jalan.net/yad{HotelID}/` is the canonical address — the same
    /// number the API returns as `HotelID`. The `HotelDetailURL` in a search
    /// response goes through `JwsRedirect.do` instead and carries the API key in
    /// the query, so it is not what should be handed to an affiliate link.
    public func hotelPageURL(hotelID: String, stay: StayConditions? = nil) -> URL? {
        guard !hotelID.isEmpty else { return nil }
        var components = URLComponents(string: "https://www.jalan.net/yad\(hotelID)/")
        components?.queryItems = (stay ?? StayConditions()).jalanWebQueryItems
        return components?.url
    }

    /// The inn's page, already wrapped for the affiliate programme.
    public func referralURL(hotelID: String, stay: StayConditions? = nil) -> URL? {
        hotelPageURL(hotelID: hotelID, stay: stay).map { referralURL(for: $0) }
    }
}

extension StayConditions {
    /// jalan.net's own query names, which differ from the API's — the booking
    /// site takes `adultNum`/`roomCount`/`stayYear`, the API takes
    /// `adult_num`/`room_count`/`stay_year`.
    var jalanWebQueryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let checkIn {
            let parts = Self.calendar.dateComponents([.year, .month, .day], from: checkIn)
            if let year = parts.year, let month = parts.month, let day = parts.day {
                items += [
                    URLQueryItem(name: "stayYear", value: String(year)),
                    URLQueryItem(name: "stayMonth", value: String(month)),
                    URLQueryItem(name: "stayDay", value: String(day))
                ]
            }
        } else {
            items.append(URLQueryItem(name: "dateUndecided", value: "1"))
        }
        items += [
            URLQueryItem(name: "stayCount", value: String(nights)),
            URLQueryItem(name: "adultNum", value: String(party.adults)),
            URLQueryItem(name: "roomCount", value: String(rooms))
        ]
        return items
    }
}

private extension URL {
    var isJalanAddress: Bool {
        guard let host = host()?.lowercased() else { return false }
        return host == "jalan.net" || host.hasSuffix(".jalan.net")
    }

    /// Percent-encodes the whole URL, leaving only the unreserved characters —
    /// `:` and `/` included, which is what the redirect expects in `vc_url`.
    var fullyPercentEncoded: String? {
        var unreserved = CharacterSet.alphanumerics
        unreserved.insert(charactersIn: "-._~")
        return absoluteString.addingPercentEncoding(withAllowedCharacters: unreserved)
    }
}
