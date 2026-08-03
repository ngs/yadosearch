import Foundation
import YadoSearchCore

/// Where a navigation stack in this app can go.
enum SearchRoute: Hashable {
    /// The whole search — target, filters, party and the phrase that names it.
    /// The same value the recent-search list stores and replays.
    case results(SavedSearch)
    case hotel(Hotel)
}
