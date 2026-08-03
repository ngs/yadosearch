import Foundation
import YadoSearchCore

/// Turns an error into the line the user reads.
///
/// The service's own refusals are passed through verbatim: they are Japanese
/// prose aimed at the caller ("宿名による宿の検索結果が200件を越えています。検索
/// キーワードを変更してください。") and they say more about what to do next than
/// any generic wording could. Nothing here mentions the API key — it is the
/// developer's problem, not something a user of the app can act on.
public func searchErrorMessage(for error: Error) -> String {
    guard let apiError = error as? JalanAPIError else {
        return error.localizedDescription
    }
    switch apiError {
    case let .service(message) where !message.isEmpty:
        return message
    case .service, .malformedResponse:
        return "サーバーからの応答を読み取れませんでした。"
    case let .transport(description):
        return description
    }
}
