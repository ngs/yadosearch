import Foundation
import YadoSearchCore

/// Turns an error into the line the user reads.
///
/// The service's own refusals are passed through verbatim: they are Japanese
/// prose aimed at the caller ("宿名による宿の検索結果が200件を越えています。検索
/// キーワードを変更してください。") and they say more about what to do next than
/// any generic wording could. The proxy forwards them unchanged, so this still
/// holds now that nothing talks to Jalan directly.
public func searchErrorMessage(for error: Error) -> String {
    guard let apiError = error as? APIError else {
        return error.localizedDescription
    }
    if apiError.meansRateLimited {
        // The upstream wording for this is "rakuten:  (status 429)", which
        // says nothing to anyone. It is also temporary, which is the part
        // worth saying.
        return String(localized: "The booking site is busy. Try again in a moment.")
    }

    switch apiError {
    case let .service(message) where !message.isEmpty:
        return message
    case .service, .malformedResponse:
        return String(localized: "The server's response could not be read.")
    case let .transport(description):
        return description
    }
}
