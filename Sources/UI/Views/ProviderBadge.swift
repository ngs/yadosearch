import SwiftUI
import YadoSearchCore

/// Which site this came from, in that site's own colour.
///
/// On a result row it says where the inn was found; on a plan it says who is
/// selling it — the same badge in both places, because it answers the same
/// question and a reader should not have to learn it twice.
struct ProviderBadge: View {
    let provider: Provider

    var body: some View {
        Text(provider.title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(provider.tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(provider.tint.opacity(0.15), in: .capsule)
    }
}

extension Provider {
    /// Each site's own brand colour, sampled from its logo: じゃらん's orange
    /// and 楽天トラベル's green, lifted a little for dark mode.
    ///
    /// They live in the app's asset catalogue rather than as literals here,
    /// because more than one screen wears them — and they resolve against
    /// `Bundle.main` for the same reason the string catalogue does: the
    /// catalogue is in the app target, and this is a package.
    var tint: Color {
        switch self {
        case .jalan: Color("JalanTint")
        case .rakuten: Color("RakutenTint")
        }
    }
}

#Preview {
    HStack {
        ProviderBadge(provider: .jalan)
        ProviderBadge(provider: .rakuten)
    }
}
