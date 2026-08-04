import SwiftUI
import YadoSearchPlatform

/// The app's four top-level places — the same four the 2010 release had.
///
/// Three shapes, because no one arrangement survives every platform:
///
/// - **iPhone**: a `TabView` at the root, each tab owning its own
///   `NavigationStack`, the inn pushed as a `SearchRoute` like any other.
/// - **iPad**: the tabs and whatever each pushed on the left, the inn on the
///   right — choosing another inn from a list of results should not take the
///   list away on a screen this wide. The push-inside-sidebar arrangement the
///   Mac cannot draw works fine here.
/// - **Mac**: three columns — places, what they lead to, the inn — because a
///   `NavigationStack` push inside a `TabView` inside a split view's *sidebar*
///   draws nothing there: title and back button and no content, whatever the
///   destination is. Verified against the running app; do not fold the shapes
///   back into one without re-checking that.
public struct YadoSearchRootView: View {
    #if os(macOS)
    /// One of the four places. Never nil in practice — the sidebar always has
    /// a selection — but the split view wants an optional.
    @State private var place: Place? = .search
    @State private var columns = NavigationSplitViewVisibility.all
    #else
    @State private var columns = NavigationSplitViewVisibility.doubleColumn
    #endif
    /// The inn on the right, where there is a right: one piece of state for
    /// the whole window, because the detail column belongs to the window, not
    /// to whichever list filled it. iPhone has no detail column and leaves
    /// this alone — its lists push instead.
    @State private var selectedHotel: HotelReference?

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
    #else
    public var body: some View {
        // The `TabView` is the outermost thing and the split views live
        // *inside* the tabs, never the other way round: a `TabView` in a
        // split view's sidebar column swallows every tab's root navigation
        // bar — no title, no toolbar, no edit mode — and draws the tab bar
        // sideways for good measure.
        TabView {
            Tab("Search", systemImage: "magnifyingglass") {
                columned { SearchView(selectedHotel: $selectedHotel) }
            }
            Tab(StoredHotel.Kind.favorite.title, systemImage: "heart") {
                columned { StoredHotelListView(kind: .favorite, selectedHotel: $selectedHotel) }
            }
            Tab(StoredHotel.Kind.history.title, systemImage: "clock") {
                columned { StoredHotelListView(kind: .history, selectedHotel: $selectedHotel) }
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        // A plain tab bar everywhere: `.sidebarAdaptable` would offer to
        // spread the four tabs into a second sidebar beside the split views'
        // own columns.
        .tabViewStyle(.tabBarOnly)
    }

    /// The list beside the inn it opened, on the iPad; just the list on the
    /// iPhone, which pushes the inn instead and has no second column to fill.
    @ViewBuilder
    private func columned(@ViewBuilder list: () -> some View) -> some View {
        if hotelOpensInDetailColumn {
            NavigationSplitView(columnVisibility: $columns) {
                list()
                    // Left to itself the column settles narrow enough to wrap
                    // an inn's name into a vertical sliver. A results list
                    // needs the width of a results list.
                    .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 520)
            } detail: {
                detail
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            list()
        }
    }
    #endif

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
