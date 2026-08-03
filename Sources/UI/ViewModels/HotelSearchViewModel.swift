import Foundation
import Observation
import YadoSearchCore

/// Runs one search and pages through it.
///
/// One instance per results screen: the target is fixed at construction, which is
/// what lets paging state and the list stay in step without a reset path.
@MainActor
@Observable
public final class HotelSearchViewModel {
    public enum Phase: Equatable {
        case loading
        case loaded
        /// The message is the service's own, when it gave one — it explains the
        /// refusal better than anything this layer could invent.
        case failed(String)
    }

    public private(set) var hotels: [Hotel] = []
    public private(set) var numberOfResults = 0
    public private(set) var phase: Phase = .loading
    public private(set) var isLoadingMore = false

    public let target: SearchTarget
    public let filters: SearchFilters
    public let party: GuestParty?

    private let client: JalanAPIClient
    private var nextStart: Int? = 1

    public init(
        client: JalanAPIClient,
        target: SearchTarget,
        filters: SearchFilters = SearchFilters(),
        party: GuestParty? = nil
    ) {
        self.client = client
        self.target = target
        self.filters = filters
        self.party = party
    }

    /// The point a proximity search was centred on, for the distance labels.
    public var searchCentre: GeoCoordinate? {
        guard case let .around(coordinate, _) = target else { return nil }
        return coordinate
    }

    public func distance(to hotel: Hotel) -> Double? {
        guard let centre = searchCentre, let coordinate = hotel.coordinate else { return nil }
        return centre.distance(to: coordinate)
    }

    public var canLoadMore: Bool { nextStart != nil }

    public func load() async {
        phase = .loading
        hotels = []
        numberOfResults = 0
        nextStart = 1
        await loadNextPage()
    }

    /// Called as rows appear. Fires only for the tail of the list, and never
    /// while a page is already in flight.
    public func loadMoreIfNeeded(currentItem: Hotel) async {
        guard !isLoadingMore, nextStart != nil, phase == .loaded else { return }
        let threshold = hotels.index(hotels.endIndex, offsetBy: -5, limitedBy: hotels.startIndex)
            ?? hotels.startIndex
        guard let index = hotels.firstIndex(of: currentItem), index >= threshold else { return }
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard let start = nextStart else { return }
        isLoadingMore = !hotels.isEmpty
        defer { isLoadingMore = false }

        do {
            let page = try await client.searchHotels(
                HotelSearchQuery(
                    target: target,
                    filters: filters,
                    party: party,
                    start: start,
                    count: 30
                )
            )
            hotels += page.items
            numberOfResults = page.numberOfResults
            nextStart = page.nextStart
            phase = .loaded
        } catch {
            // A failed follow-up page must not throw away the rows already shown.
            if hotels.isEmpty {
                phase = .failed(searchErrorMessage(for: error))
            }
            nextStart = nil
        }
    }
}
