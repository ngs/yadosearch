import SwiftUI
import YadoSearchPlatform

/// The app's four top-level places — the same four the 2010 release had.
///
/// `sidebarAdaptable` is what makes one declaration serve all three shapes: a tab
/// bar on iPhone, a sidebar that collapses to a tab bar on iPad, and a source
/// list on the Mac.
public struct YadoSearchRootView: View {
    public init() {}

    public var body: some View {
        TabView {
            Tab("さがす", systemImage: "magnifyingglass") {
                SearchView()
            }
            Tab(StoredHotel.Kind.favorite.title, systemImage: "heart") {
                StoredHotelListView(kind: .favorite)
            }
            Tab(StoredHotel.Kind.history.title, systemImage: "clock") {
                StoredHotelListView(kind: .history)
            }
            Tab("設定", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    YadoSearchRootView()
}
