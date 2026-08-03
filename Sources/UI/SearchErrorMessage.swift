import Foundation
import YadoSearchCore

/// Turns an error into the line the user reads.
///
/// The service's own refusals are passed through verbatim: they are Japanese
/// prose aimed at the caller ("宿名による宿の検索結果が200件を越えています。検索
/// キーワードを変更してください。") and they say more about what to do next than
/// any generic wording could.
public func searchErrorMessage(for error: Error) -> String {
    guard let apiError = error as? JalanAPIError else {
        return error.localizedDescription
    }
    switch apiError {
    case .missingApplicationKey:
        return "じゃらんのAPIキーが設定されていません。"
    case let .service(message) where !message.isEmpty:
        return message
    case .service, .malformedResponse:
        return "サーバーからの応答を読み取れませんでした。"
    case let .transport(description):
        return description
    }
}
