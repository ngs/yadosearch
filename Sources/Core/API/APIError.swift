import Foundation

/// A request that could not be answered at all.
///
/// One provider failing is *not* this: that comes back as a normal response
/// with an entry in its `errors` map, because the other provider's results are
/// still worth showing.
public enum APIError: Error, Sendable, Equatable {
    /// The proxy answered `{"error": "…"}`. The text is written for the caller
    /// — often verbatim from the upstream service, in Japanese — so it is worth
    /// showing as it stands rather than replacing.
    case service(message: String)
    case transport(description: String)
    case malformedResponse
}

public extension APIError {
    /// Rakuten reports "nothing matched" as a *failure*: `{"error":"Data Not
    /// Found"}` with a 502, where Jalan answers 200 and `"total": 0`. Shown as
    /// it stands, that reads as a broken app rather than as an empty result —
    /// which is what a plan search with a date most often is.
    var meansNoResults: Bool {
        guard case let .service(message) = self else { return false }
        return message.localizedCaseInsensitiveContains("data not found")
            || message.localizedCaseInsensitiveContains("not found")
    }

    /// Rakuten's rate limit, which is easy to hit and passes for a fault: the
    /// proxy forwards it as `rakuten: (status 429)`. It is worth saying so in
    /// words, and worth offering to try again.
    var meansRateLimited: Bool {
        guard case let .service(message) = self else { return false }
        return message.contains("429")
            || message.localizedCaseInsensitiveContains("too many requests")
            || message.localizedCaseInsensitiveContains("rate limit")
    }
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .malformedResponse:
            nil
        case let .service(message):
            message
        case let .transport(description):
            description
        }
    }
}
