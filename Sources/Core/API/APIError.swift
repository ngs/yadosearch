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
