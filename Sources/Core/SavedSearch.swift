import Foundation

/// A search, whole: where to look, how to narrow it, and the phrase that
/// describes it.
///
/// The title is carried rather than derived because it cannot be rebuilt later —
/// "東京都千代田区から約2.5km" needs the reverse-geocoded place name that was
/// resolved at the time, and "浅草" needs the area name that the code alone does
/// not give back.
public struct SavedSearch: Sendable, Hashable, Codable, Identifiable {
    public var target: SearchTarget
    public var filters: SearchFilters
    public var party: GuestParty?
    public var title: String

    public init(
        target: SearchTarget,
        filters: SearchFilters = SearchFilters(),
        party: GuestParty? = nil,
        title: String
    ) {
        self.target = target
        self.filters = filters
        self.party = party
        self.title = title
    }

    /// Identity is what the search *does*, not what it is called: re-running the
    /// same conditions should move one entry to the top of the recents rather
    /// than add a second one that looks identical.
    public var id: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(Fingerprint(self)) else {
            return title
        }
        return String(bytes: data, encoding: .utf8) ?? title
    }

    /// A flattened, ordered view of the conditions.
    ///
    /// `SearchFilters` cannot be encoded directly here: its amenities are a
    /// `Set`, and a set serialises in whatever order it happens to iterate, so
    /// two equal filter sets would fingerprint differently.
    private struct Fingerprint: Encodable {
        let target: SearchTarget
        let sortOrder: Int
        let hotelType: Int?
        let minimumRate: Int?
        let maximumRate: Int?
        let amenities: [String]
        let party: GuestParty?

        init(_ search: SavedSearch) {
            target = search.target
            sortOrder = search.filters.sortOrder.rawValue
            hotelType = search.filters.hotelType?.rawValue
            minimumRate = search.filters.minimumRate
            maximumRate = search.filters.maximumRate
            amenities = search.filters.amenities.map(\.rawValue).sorted()
            party = search.party
        }
    }
}

public extension SavedSearch {
    /// "旅館・温泉・大人2名" — what was narrowed, for the second line of a
    /// recents row. Empty when nothing was.
    var conditionsSummary: String {
        var parts: [String] = []
        if filters.sortOrder != .unspecified {
            parts.append(filters.sortOrder.title)
        }
        if let hotelType = filters.hotelType {
            parts.append(hotelType.title)
        }
        if let budget = filters.budgetSummary {
            parts.append(budget)
        }
        if let amenities = filters.amenitySummary {
            parts.append(amenities)
        }
        return parts.joined(separator: "・")
    }
}
