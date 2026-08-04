import Foundation
import YadoSearchCore
#if canImport(UIKit)
import UIKit
#endif

/// Whether a chosen inn is rendered in a detail column beside its list — the
/// Mac and the iPad — rather than pushed onto the list's own stack, which is
/// all the iPhone has room for. The lists branch on this, and so does the
/// root: the answer decides whether there is a detail column at all.
var hotelOpensInDetailColumn: Bool {
    #if os(macOS)
    true
    #else
    UIDevice.current.userInterfaceIdiom == .pad
    #endif
}

/// Enough to open an inn's page: which site it is booked through, its ID there,
/// and — when the list had one — the record already fetched, so the page draws
/// before the detail request returns.
///
/// The ID alone would not do: the two sites number their inns independently and
/// the numbers collide.
struct HotelReference: Hashable {
    let provider: Provider
    let id: String
    var listing: HotelListing?

    init(provider: Provider, id: String, listing: HotelListing? = nil) {
        self.provider = provider
        self.id = id
        self.listing = listing
    }

    /// The provider a search result should open on: the one that quoted a
    /// price, else whichever came first.
    init?(listing: HotelListing) {
        let offer = listing.offers.first { $0.minimumCharge != nil } ?? listing.offers.first
        guard let offer else { return nil }
        self.init(provider: offer.provider, id: offer.id, listing: listing)
    }
}

/// Where the search tab's navigation stack can go.
///
/// The stack's path is `[SearchRoute]` — typed, because a `NavigationPath` in
/// this position renders nothing on the Mac — and a typed path can only hold
/// its own type. A `navigationDestination(item:)` push tried alongside it is
/// not representable there, and SwiftUI swaps the screen without an animation
/// and pops to the root on back. So the inn is a route like any other.
enum SearchRoute: Hashable {
    /// The whole search — target, scope, filters, party and the phrase that
    /// names it. The same value the recent-search list stores and replays.
    case results(SavedSearch)
    /// One inn, pushed from a results row. iPhone and iPad only: the Mac
    /// renders the inn in the window's detail column instead of pushing it.
    case hotel(HotelReference)
}
