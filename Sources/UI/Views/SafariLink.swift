import SwiftUI
#if !os(macOS)
import SafariServices
#endif

/// A link that opens in an in-app browser instead of handing the URL to the
/// system.
///
/// Affiliate links have to stay in the browser. `ck.jp.ap.valuecommerce.com`
/// redirects to jalan.net, and jalan.net publishes a universal link: opened
/// with `Link` (or `openURL`), iOS hands the redirect to the じゃらん app and the
/// referral never completes, so the click earns nothing.
/// `SFSafariViewController` does not honour universal links, so the redirect
/// always lands in the browser and the referral survives.
///
/// On macOS there is no じゃらん app and no `SFSafariViewController`, so this is
/// a plain `Link`.
struct SafariLink<Label: View>: View {
    let url: URL
    let label: Label

    #if os(macOS)
    @Environment(\.openURL) private var openURL
    #else
    @State private var isPresented = false
    #endif

    init(destination url: URL, @ViewBuilder label: () -> Label) {
        self.url = url
        self.label = label()
    }

    var body: some View {
        #if os(macOS)
        // A `Link` in a toolbar draws as link-blue text-or-icon, out of step
        // with every button beside it. A button that opens the URL is the same
        // action and looks like the toolbar it is in.
        Button {
            openURL(url)
        } label: {
            label
        }
        #else
        Button {
            isPresented = true
        } label: {
            label
        }
        .sheet(isPresented: $isPresented) {
            SafariViewControllerView(url: url)
                .ignoresSafeArea()
        }
        #endif
    }
}

#if !os(macOS)
private struct SafariViewControllerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context _: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_: SFSafariViewController, context _: Context) {}
}
#endif
