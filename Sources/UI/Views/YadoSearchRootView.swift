import SwiftUI
import YadoSearchPlatform

/// The app's four top-level places — the same four the 2010 release had —
/// beside the inn currently being read.
///
/// Two columns rather than one stack: the tabs and whatever each of them has
/// pushed stay on the left, and the inn opens on the right, so choosing another
/// inn from a list of results does not take the list away. On iPhone the split
/// view collapses and the same choice pushes, which is what it always did.
public struct YadoSearchRootView: View {
    /// The inn on the right. One piece of state for all four tabs: the detail
    /// column belongs to the window, not to whichever list happened to fill it.
    @State private var selectedHotel: HotelReference?
    @State private var columns = NavigationSplitViewVisibility.doubleColumn

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            TabView {
                Tab("Search", systemImage: "magnifyingglass") {
                    SearchView(selectedHotel: $selectedHotel)
                }
                Tab(StoredHotel.Kind.favorite.title, systemImage: "heart") {
                    StoredHotelListView(kind: .favorite, selectedHotel: $selectedHotel)
                }
                Tab(StoredHotel.Kind.history.title, systemImage: "clock") {
                    StoredHotelListView(kind: .history, selectedHotel: $selectedHotel)
                }
                Tab("Settings", systemImage: "gearshape") {
                    SettingsView()
                }
            }
            // No `.sidebarAdaptable` any more: the sidebar is the split view's
            // now, and a tab bar that turns into a second sidebar inside it
            // would be a sidebar within a sidebar.
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detail: some View {
        if let selectedHotel {
            // Keyed by the inn, so switching from one result to another builds
            // a fresh page rather than re-using the last one's state.
            HotelDetailView(reference: selectedHotel)
                .id(selectedHotel)
        } else {
            ContentUnavailableView {
                Label("No inn selected", systemImage: "bed.double")
            } description: {
                Text("Choose an inn from a search and it appears here.")
            }
        }
    }
}

#Preview {
    YadoSearchRootView()
}
