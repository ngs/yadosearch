import SwiftUI
import YadoSearchPlatform

/// The app's four top-level places — the same four the 2010 release had.
///
/// Two shapes, chosen at compile time, because no one arrangement survives
/// both platforms:
///
/// - **iPhone / iPad**: a `TabView` at the root, each tab owning its own
///   `NavigationStack`, the inn pushed within it by
///   `navigationDestination(item:)`. Nesting the `TabView` inside a
///   `NavigationSplitView`'s sidebar — the previous shape — left a selection
///   binding with nowhere to push to, so tapping a result did nothing.
/// - **Mac**: three columns — places, what they lead to, the inn — because a
///   `NavigationStack` push inside a `TabView` inside a split view's *sidebar*
///   draws nothing there: title and back button and no content, whatever the
///   destination is. Verified against the running app; do not fold the two
///   shapes back into one without re-checking that.
public struct YadoSearchRootView: View {
    #if os(macOS)
    /// One of the four places. Never nil in practice — the sidebar always has
    /// a selection — but the split view wants an optional.
    @State private var place: Place? = .search
    /// The inn on the right. One piece of state for all four places: the
    /// detail column belongs to the window, not to whichever list filled it.
    @State private var selectedHotel: HotelReference?
    @State private var columns = NavigationSplitViewVisibility.all
    #else
    // One selection per tab, not one for the window: each tab's stack pushes
    // its own inn, and a shared item would make every stack push at once.
    @State private var searchHotel: HotelReference?
    @State private var favoriteHotel: HotelReference?
    @State private var historyHotel: HotelReference?
    #endif

    public init() {}

    #if os(macOS)
    public var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $place) {
                ForEach(Place.allCases) { place in
                    Label(place.title, systemImage: place.systemImage)
                        .tag(place)
                }
            }
            .navigationTitle("YadoSearch")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } content: {
            content
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 520)
        } detail: {
            detail
        }
    }

    @ViewBuilder
    private var content: some View {
        switch place ?? .search {
        case .search:
            SearchView(selectedHotel: $selectedHotel)
        case .favorites:
            StoredHotelListView(kind: .favorite, selectedHotel: $selectedHotel)
        case .history:
            StoredHotelListView(kind: .history, selectedHotel: $selectedHotel)
        case .settings:
            SettingsView()
        }
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
    #else
    public var body: some View {
        TabView {
            Tab("Search", systemImage: "magnifyingglass") {
                SearchView(selectedHotel: $searchHotel)
            }
            Tab(StoredHotel.Kind.favorite.title, systemImage: "heart") {
                StoredHotelListView(kind: .favorite, selectedHotel: $favoriteHotel)
            }
            Tab(StoredHotel.Kind.history.title, systemImage: "clock") {
                StoredHotelListView(kind: .history, selectedHotel: $historyHotel)
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        // A tab bar on iPhone; on iPad the same tabs can spread into a
        // sidebar, which is what the platform does with content apps now.
        .tabViewStyle(.sidebarAdaptable)
    }
    #endif
}

#if os(macOS)
/// The four top-level places, in the order the 2010 release had them.
enum Place: String, CaseIterable, Identifiable, Hashable {
    case search
    case favorites
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: String(localized: "Search")
        case .favorites: StoredHotel.Kind.favorite.title
        case .history: StoredHotel.Kind.history.title
        case .settings: String(localized: "Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .search: "magnifyingglass"
        case .favorites: StoredHotel.Kind.favorite.systemImage
        case .history: StoredHotel.Kind.history.systemImage
        case .settings: "gearshape"
        }
    }
}
#endif

#Preview {
    YadoSearchRootView()
}
