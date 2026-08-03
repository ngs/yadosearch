import Foundation
import Observation
import YadoSearchCore

/// Backs the detail screen: the full inn record, and the plans on offer.
///
/// The screen is about one inn, but that inn is carried by up to two booking
/// sites, and everything bookable — the ID, the plans, the price, the link — is
/// per site. So the provider is a piece of state here, the segmented control
/// sets it, and changing it re-runs the plan search against the other site.
@MainActor
@Observable
public final class HotelDetailViewModel {
    public enum PlansPhase: Equatable {
        case idle
        case loading
        case loaded
        /// Rakuten has no undated mode, so it cannot be asked anything until a
        /// check-in date is chosen. That is a prompt, not a failure.
        case needsCheckIn
        case failed(String)
    }

    /// What the list already knew, so the page renders before anything loads.
    public private(set) var listing: HotelListing?
    /// The full record, once fetched. Carries the counterpart on the other
    /// provider, which is what the segmented control offers.
    public private(set) var detail: HotelDetailResponse?
    public private(set) var plans: [StayPlan] = []
    public private(set) var plansPhase: PlansPhase = .idle
    public private(set) var numberOfPlans = 0

    /// Which site the page is currently showing. Starts as the one the search
    /// result came from.
    public var provider: Provider {
        didSet {
            guard provider != oldValue else { return }
            reload()
        }
    }

    public var stay: StayConditions {
        didSet {
            guard stay != oldValue else { return }
            reload()
        }
    }

    private let client: YadoSearchAPIClient
    private var reloadTask: Task<Void, Never>?

    public init(
        provider: Provider,
        listing: HotelListing? = nil,
        client: YadoSearchAPIClient,
        stay: StayConditions = StayConditions()
    ) {
        self.provider = provider
        self.listing = listing
        self.client = client
        self.stay = stay
    }

    /// The inn's ID on the provider currently selected. `nil` while the detail
    /// is still loading and the list knew of no offer from that side.
    public var hotelID: String? {
        detail?.profile(for: provider)?.id ?? listing?.offer(from: provider)?.id
    }

    /// The record to draw the page from: the selected provider's account of the
    /// inn, falling back to the other one's for the facts it omits.
    public var profile: HotelProfile? {
        detail?.profile(for: provider) ?? detail?.hotel
    }

    /// The sites this inn can be booked through. One entry means no segmented
    /// control is worth drawing.
    public var availableProviders: [Provider] {
        if let detail { return detail.availableProviders }
        guard let listing else { return [provider] }
        return Provider.allCases.filter { listing.offer(from: $0) != nil }
    }

    /// Where the booking button goes for the selected provider. Already
    /// affiliate-wrapped by the proxy.
    public var bookingURL: URL? {
        detail?.profile(for: provider)?.detailURL ?? listing?.offer(from: provider)?.detailURL
    }

    /// The cheapest quoted stay, for the summary line.
    public var lowestRate: Int? {
        plans.compactMap { $0.totalRate ?? $0.sampleRate }.min()
    }

    public func load() async {
        await loadDetail()
        await loadPlans()
    }

    private func reload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            await self?.loadPlans()
        }
    }

    /// Reads the inn by provider and ID. Silent on failure: the page already
    /// has a usable record from the list, and an error banner over a working
    /// screen helps nobody.
    private func loadDetail() async {
        guard let id = hotelID else { return }
        detail = try? await client.hotel(provider: provider, id: id)
    }

    public func loadPlans() async {
        guard provider != .rakuten || stay.checkIn != nil else {
            plans = []
            numberOfPlans = 0
            plansPhase = .needsCheckIn
            return
        }
        guard let id = hotelID else { return }

        let request = StayRequest(
            checkIn: stay.checkIn,
            nights: stay.nights,
            rooms: stay.rooms,
            adults: stay.party.adults
        )

        plansPhase = .loading
        do {
            let page = try await fetchPlans(provider: provider, id: id, request: request)
            guard !Task.isCancelled else { return }
            plans = page.plans
            numberOfPlans = page.total
            plansPhase = .loaded
        } catch {
            guard !Task.isCancelled else { return }
            plans = []
            numberOfPlans = 0
            // "Nothing on offer" arrives as a failure from Rakuten and as an
            // empty page from Jalan. It is the same answer, and the screen
            // already has wording for it.
            if let apiError = error as? APIError, apiError.meansNoResults {
                plansPhase = .loaded
            } else {
                plansPhase = .failed(searchErrorMessage(for: error))
            }
        }
    }

    /// Asks once, and asks again if 楽天 said it was busy.
    ///
    /// Its rate limit is shared and easy to trip — reading two inns in quick
    /// succession is enough — and it clears in about a second. One retry turns
    /// most of those into the answer the user asked for; a second would only
    /// make the screen sit there longer.
    private func fetchPlans(
        provider: Provider,
        id: String,
        request: StayRequest
    ) async throws -> PlanPage {
        do {
            return try await client.plans(provider: provider, hotelID: id, stay: request, count: 30)
        } catch let error as APIError where error.meansRateLimited {
            try await Task.sleep(for: .milliseconds(1_200))
            try Task.checkCancellation()
            return try await client.plans(provider: provider, hotelID: id, stay: request, count: 30)
        }
    }
}
