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

    public private(set) var listings: [HotelListing] = []
    /// Hits per provider before merging. These do not add up to `listings.count`
    /// and routinely disagree with each other, so they are shown as a breakdown
    /// rather than as one number.
    public private(set) var totals: [Provider: Int] = [:]
    /// What a provider said when it could not answer. One side failing still
    /// leaves the other's results on screen, so this is a note beside the list
    /// rather than an error state.
    public private(set) var providerErrors: [Provider: String] = [:]
    public private(set) var phase: Phase = .loading
    public private(set) var isLoadingMore = false

    public let target: SearchTarget
    public let scope: SearchScope
    public let filters: SearchFilters
    public let party: GuestParty?

    private let client: YadoSearchAPIClient
    private let pageSize = 30
    private var nextPage: Int? = 1

    public init(
        client: YadoSearchAPIClient,
        target: SearchTarget,
        scope: SearchScope = .both,
        filters: SearchFilters = SearchFilters(),
        party: GuestParty? = nil
    ) {
        self.client = client
        self.target = target
        self.scope = scope
        self.filters = filters
        self.party = party
    }

    /// The point a proximity search was centred on, for the distance labels.
    public var searchCentre: GeoCoordinate? {
        guard case let .around(coordinate, _) = target else { return nil }
        return coordinate
    }

    /// Metres from the search centre, preferring the provider's own figure —
    /// it is measured against the coordinate actually searched from.
    public func distance(to listing: HotelListing) -> Double? {
        if let reported = listing.distanceMetres { return reported }
        guard let centre = searchCentre, let coordinate = listing.coordinate else { return nil }
        return centre.distance(to: coordinate)
    }

    public var canLoadMore: Bool { nextPage != nil }

    /// True when the filters narrowed Jalan's half of the results but not
    /// Rakuten's, which is every filtered search that reached both.
    public var filtersAppliedToJalanOnly: Bool {
        !filters.isEmpty && totals[.rakuten] != nil
    }

    public func load() async {
        phase = .loading
        listings = []
        totals = [:]
        providerErrors = [:]
        nextPage = 1
        await loadNextPage()
    }

    /// Called as rows appear. Fires only for the tail of the list, and never
    /// while a page is already in flight.
    public func loadMoreIfNeeded(currentItem: HotelListing) async {
        guard !isLoadingMore, nextPage != nil, phase == .loaded else { return }
        let threshold = listings.index(listings.endIndex, offsetBy: -5, limitedBy: listings.startIndex)
            ?? listings.startIndex
        guard let index = listings.firstIndex(of: currentItem), index >= threshold else { return }
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard let page = nextPage else { return }
        isLoadingMore = !listings.isEmpty
        defer { isLoadingMore = false }

        do {
            let response = try await client.searchHotels(
                HotelSearchRequest(
                    target: target,
                    scope: scope,
                    filters: filters,
                    party: party,
                    page: page,
                    count: pageSize
                )
            )
            // The proxy matches inns across providers within one response, not
            // across pages, so the same inn can arrive again on a later page
            // under a different pairing. Dropping repeats keeps the list honest.
            let known = Set(listings.map(\.id))
            listings += response.results.filter { !known.contains($0.id) }
            totals = response.totals
            providerErrors = response.errors ?? [:]
            nextPage = Self.pageAfter(page, requested: page * pageSize, response: response)
            phase = .loaded
        } catch is CancellationError {
            // The task died with the screen, not the search — a tab switch
            // cancels the view's `.task` mid-flight. Leave the phase and the
            // page counter as they are; the next appearance resumes them.
        } catch let error as URLError where error.code == .cancelled {
            // The same death, reported URLSession's way.
        } catch {
            // A failed follow-up page must not throw away the rows already shown.
            if listings.isEmpty {
                phase = .failed(searchErrorMessage(for: error))
            }
            nextPage = nil
        }
    }

    /// `count` is per provider, so how much is left is a question about the
    /// per-provider totals rather than about the merged row count.
    private static func pageAfter(
        _ page: Int,
        requested: Int,
        response: SearchResponse
    ) -> Int? {
        guard !response.results.isEmpty else { return nil }
        return response.totals.values.contains { $0 > requested } ? page + 1 : nil
    }
}
