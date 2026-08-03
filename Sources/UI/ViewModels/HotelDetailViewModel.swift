import Foundation
import Observation
import YadoSearchCore

/// Backs the detail screen: the full inn record, and the plans on offer.
///
/// The two loads are independent and shown independently. The inn arrives from
/// the list already good enough to render the page, so a plan search that fails —
/// which it does whenever nothing is bookable on the chosen dates — leaves the
/// rest of the screen intact.
@MainActor
@Observable
public final class HotelDetailViewModel {
    public enum PlansPhase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// Starts as the record the list had, and is replaced once the detail
    /// request returns the fields a search response leaves out (access
    /// directions, check-in times, the kana reading).
    public private(set) var hotel: Hotel
    public private(set) var plans: [Plan] = []
    public private(set) var plansPhase: PlansPhase = .idle
    public private(set) var numberOfPlans = 0

    public var stay: StayConditions {
        didSet {
            guard stay != oldValue else { return }
            reloadPlansTask?.cancel()
            reloadPlansTask = Task { [weak self] in
                await self?.loadPlans()
            }
        }
    }

    private let client: JalanAPIClient?
    private var reloadPlansTask: Task<Void, Never>?

    public init(hotel: Hotel, client: JalanAPIClient?, stay: StayConditions = StayConditions()) {
        self.hotel = hotel
        self.client = client
        self.stay = stay
    }

    public func load() async {
        async let detail: Void = refreshHotel()
        async let plans: Void = loadPlans()
        _ = await (detail, plans)
    }

    /// Re-reads the inn by ID. Silent on failure: the page already has a usable
    /// record, and an error banner over a working screen helps nobody.
    private func refreshHotel() async {
        guard let client else { return }
        guard
            let page = try? await client.searchHotels(HotelSearchQuery(target: .hotel(id: hotel.id), count: 1)),
            let refreshed = page.items.first
        else {
            return
        }
        hotel = refreshed
    }

    public func loadPlans() async {
        guard let client else {
            plansPhase = .failed(searchErrorMessage(for: JalanAPIError.missingApplicationKey))
            return
        }
        plansPhase = .loading
        do {
            let page = try await client.searchPlans(
                PlanSearchQuery(target: .hotel(id: hotel.id), stay: stay, count: 30)
            )
            guard !Task.isCancelled else { return }
            plans = page.items
            numberOfPlans = page.numberOfResults
            plansPhase = .loaded
        } catch {
            guard !Task.isCancelled else { return }
            plans = []
            numberOfPlans = 0
            plansPhase = .failed(searchErrorMessage(for: error))
        }
    }

    /// The cheapest representative rate on offer, for the summary line.
    public var lowestRate: Int? {
        plans.compactMap(\.sampleRate).min()
    }
}
