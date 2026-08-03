import Foundation
import YadoSearchCore

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

/// Where a navigation stack in this app can go.
enum SearchRoute: Hashable {
    /// The whole search — target, filters, party and the phrase that names it.
    /// The same value the recent-search list stores and replays.
    case results(SavedSearch)
    case hotel(HotelReference)
}
