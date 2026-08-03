import SwiftUI

/// Shown instead of a search when the build has no Jalan application key.
///
/// This is the normal state of a CI build, and of a checkout someone has just
/// cloned, so it explains the fix rather than reading as a failure.
struct NotConfiguredView: View {
    var body: some View {
        ContentUnavailableView {
            Label("APIキーが未設定です", systemImage: "key.slash")
        } description: {
            Text("じゃらん Web サービスのキーがこのビルドに含まれていません。プロジェクト直下の .env に JALAN_API_KEY を書き、Scripts/generate.sh を実行してビルドし直してください。")
        }
    }
}

#Preview {
    NotConfiguredView()
}
