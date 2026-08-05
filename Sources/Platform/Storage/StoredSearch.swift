import Foundation
import SwiftData
import YadoSearchCore

/// A search the user has run, kept so it can be run again.
///
/// The conditions are stored as the JSON of a `SavedSearch` rather than as
/// columns: `SearchTarget` is an enum with four differently shaped payloads, and
/// flattening it into a table would mean a nullable column per case and a
/// re-assembly step that could produce a target the app never built.
///
/// Every property has a default and none is unique — both are CloudKit
/// mirroring requirements. Deduplication happens in `SearchHistoryStore`
/// instead; see `StoredHotel` for the same treatment.
@Model
public final class StoredSearch {
    /// `SavedSearch.id` — a fingerprint of the conditions, so re-running a search
    /// moves the entry rather than adding a twin.
    public var fingerprint: String = ""
    public var title: String = ""
    public var conditionsSummary: String = ""
    public var payload = Data()
    public var searchedAt = Date.distantPast

    public init(search: SavedSearch, searchedAt: Date = .now) {
        fingerprint = search.id
        title = search.title
        conditionsSummary = search.conditionsSummary
        payload = (try? JSONEncoder().encode(search)) ?? Data()
        self.searchedAt = searchedAt
    }
}

public extension StoredSearch {
    /// `nil` when the stored JSON cannot be read back — which happens if the
    /// shape of `SavedSearch` changes under a record written by an older build.
    /// The row is then dropped from the list rather than crashing it.
    var search: SavedSearch? {
        try? JSONDecoder().decode(SavedSearch.self, from: payload)
    }
}

/// Reads and writes the recent-search list.
public enum SearchHistoryStore {
    /// Enough to cover "the thing I was looking at yesterday" without the list
    /// becoming something to scroll.
    public static let limit = 20

    /// Records a search, moving it to the top if it has been run before.
    public static func record(_ search: SavedSearch, in context: ModelContext) {
        // Twins can arrive from another device: the fingerprint is not a unique
        // constraint, because CloudKit mirroring forbids those.
        deduplicate(in: context)
        if let existing = entry(fingerprint: search.id, in: context) {
            existing.searchedAt = .now
            // The title can drift — a proximity search gains a place name once
            // the geocoder answers — so refresh it.
            existing.title = search.title
            existing.conditionsSummary = search.conditionsSummary
        } else {
            context.insert(StoredSearch(search: search))
        }
        trim(in: context)
        try? context.save()
    }

    /// Collapses searches that share a fingerprint into the newest of them.
    ///
    /// Two rows for the same conditions are not two searches, and the pair
    /// cannot be prevented at write time: `@Attribute(.unique)` crashes a
    /// CloudKit-mirrored container, so a device syncing a search it ran
    /// independently inserts a second row for it. The survivor keeps the latest
    /// `searchedAt`, which is what puts it at the top of the list.
    public static func deduplicate(in context: ModelContext) {
        var newest: [String: StoredSearch] = [:]
        var duplicates: [StoredSearch] = []

        for entry in all(in: context) {
            guard let kept = newest[entry.fingerprint] else {
                newest[entry.fingerprint] = entry
                continue
            }
            if entry.searchedAt > kept.searchedAt {
                newest[entry.fingerprint] = entry
                duplicates.append(kept)
            } else {
                duplicates.append(entry)
            }
        }

        guard !duplicates.isEmpty else { return }
        for duplicate in duplicates {
            context.delete(duplicate)
        }
        try? context.save()
    }

    public static func clear(in context: ModelContext) {
        for entry in all(in: context) {
            context.delete(entry)
        }
        try? context.save()
    }

    private static func trim(in context: ModelContext) {
        let entries = all(in: context)
        guard entries.count > limit else { return }
        for entry in entries[limit...] {
            context.delete(entry)
        }
    }

    /// Newest first.
    private static func all(in context: ModelContext) -> [StoredSearch] {
        let descriptor = FetchDescriptor<StoredSearch>(
            sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func entry(fingerprint: String, in context: ModelContext) -> StoredSearch? {
        var descriptor = FetchDescriptor<StoredSearch>(
            predicate: #Predicate { $0.fingerprint == fingerprint }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
