import Foundation

/// One page of results, with the counters the API sends alongside them.
///
/// Both search endpoints page the same way: `start` is 1-based and `count` caps
/// out at 100, and the total is reported on every page.
public struct SearchPage<Element: Sendable & Hashable>: Sendable, Hashable {
    public let numberOfResults: Int
    public let displayPerPage: Int
    public let displayFrom: Int
    public let items: [Element]

    public init(numberOfResults: Int, displayPerPage: Int, displayFrom: Int, items: [Element]) {
        self.numberOfResults = numberOfResults
        self.displayPerPage = displayPerPage
        self.displayFrom = displayFrom
        self.items = items
    }

    /// The `start` value for the next page, or `nil` when this was the last one.
    ///
    /// Derived from what actually arrived rather than from `displayPerPage`, so a
    /// short final page ends the walk instead of asking for an empty one.
    public var nextStart: Int? {
        guard !items.isEmpty else { return nil }
        let next = displayFrom + items.count
        return next > numberOfResults ? nil : next
    }
}
