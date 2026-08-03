import Foundation

public enum JalanAPIError: Error, Sendable, Equatable {
    /// The build has no application key. Everything else would fail anyway, so
    /// the client refuses before reaching the network.
    case missingApplicationKey
    /// The service answered with `<Error><Message>…</Message></Error>`. The
    /// message is Japanese prose written for the caller — "宿名による宿の検索結果
    /// が200件を越えています" and the like — and is worth showing as it stands.
    case service(message: String)
    case transport(description: String)
    case malformedResponse
}

extension JalanAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingApplicationKey, .malformedResponse:
            nil
        case let .service(message):
            message
        case let .transport(description):
            description
        }
    }
}
