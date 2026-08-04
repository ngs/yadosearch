import Foundation
import SwiftData
import Testing
import YadoSearchCore
@testable import YadoSearchPlatform

@Suite("Recent searches")
@MainActor
struct SearchHistoryStoreTests {
    private func makeContext() -> ModelContext {
        ModelContext(YadoSearchModelContainer.make(inMemory: true))
    }

    private func search(prefecture: String = "130000", title: String = "東京都") -> SavedSearch {
        SavedSearch(target: .area(AreaSelection(prefectureID: prefecture)), title: title)
    }

    private func entries(in context: ModelContext) -> [StoredSearch] {
        let descriptor = FetchDescriptor<StoredSearch>(
            sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @Test("Records a search so it can be replayed")
    func recordsASearch() throws {
        let context = makeContext()

        SearchHistoryStore.record(search(), in: context)
        let entry = try #require(entries(in: context).first)

        #expect(entry.title == "東京都")
        #expect(entry.search?.target == .area(AreaSelection(prefectureID: "130000")))
    }

    @Test("Re-running a search moves it up instead of duplicating it")
    func deduplicates() throws {
        let context = makeContext()

        SearchHistoryStore.record(search(), in: context)
        let first = try #require(entries(in: context).first).searchedAt
        SearchHistoryStore.record(search(), in: context)

        let entries = entries(in: context)
        #expect(entries.count == 1)
        #expect(try #require(entries.first).searchedAt > first)
    }

    /// A proximity search gains its place name only once the geocoder answers,
    /// so the title of an existing entry has to be refreshed.
    @Test("Twins from another device collapse into the newest, at the top")
    func mergesSyncedDuplicates() throws {
        let context = makeContext()
        let twin = search()
        // What CloudKit mirroring can produce: the same search, inserted twice,
        // because a fingerprint cannot be a unique attribute in a mirrored
        // container. Neither insert goes through `record`.
        context.insert(StoredSearch(search: twin, searchedAt: Date(timeIntervalSince1970: 1_000)))
        context.insert(StoredSearch(search: twin, searchedAt: Date(timeIntervalSince1970: 2_000)))
        context.insert(StoredSearch(
            search: search(prefecture: "010000", title: "北海道"),
            searchedAt: Date(timeIntervalSince1970: 1_500)
        ))
        try context.save()

        SearchHistoryStore.deduplicate(in: context)

        let remaining = entries(in: context)
        #expect(remaining.count == 2)
        #expect(remaining.filter { $0.fingerprint == twin.id }.count == 1)
        // The survivor is the newer of the two, which is what puts it above the
        // search that happened between them.
        #expect(remaining.first?.fingerprint == twin.id)
    }

    @Test("A changed title updates the existing entry")
    func refreshesTheTitle() throws {
        let context = makeContext()

        SearchHistoryStore.record(search(title: "現在地から約1km"), in: context)
        SearchHistoryStore.record(search(title: "東京都千代田区から約1km"), in: context)

        let entries = entries(in: context)
        #expect(entries.count == 1)
        #expect(try #require(entries.first).title == "東京都千代田区から約1km")
    }

    @Test("Different conditions are separate entries")
    func keepsDistinctSearches() {
        let context = makeContext()

        SearchHistoryStore.record(search(prefecture: "130000", title: "東京都"), in: context)
        SearchHistoryStore.record(search(prefecture: "010000", title: "北海道"), in: context)

        #expect(entries(in: context).count == 2)
    }

    @Test("The list is capped, oldest first out")
    func trimsToTheLimit() {
        let context = makeContext()
        let limit = SearchHistoryStore.limit

        for index in 0..<(limit + 5) {
            SearchHistoryStore.record(
                search(prefecture: String(format: "%06d", index), title: "検索\(index)"),
                in: context
            )
        }

        let entries = entries(in: context)
        #expect(entries.count == limit)
        #expect(!entries.contains { $0.title == "検索0" })
        #expect(entries.contains { $0.title == "検索\(limit + 4)" })
    }

    @Test("Clearing removes everything")
    func clears() {
        let context = makeContext()
        SearchHistoryStore.record(search(), in: context)

        SearchHistoryStore.clear(in: context)

        #expect(entries(in: context).isEmpty)
    }

    /// A record written by a build whose `SavedSearch` had a different shape
    /// decodes to `nil`; the row is skipped rather than crashing the list.
    @Test("An unreadable payload yields no search")
    func survivesAnUnreadablePayload() {
        let context = makeContext()
        SearchHistoryStore.record(search(), in: context)
        entries(in: context).first?.payload = Data("not json".utf8)

        #expect(entries(in: context).first?.search == nil)
    }
}
