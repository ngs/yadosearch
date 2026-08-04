import Foundation
import Testing
import YadoSearchCore
@testable import YadoSearchPlatform

/// A key-value store held in memory, standing in for `UserDefaults` and for
/// iCloud's — which is the only way to test what the two of them do together
/// without an iCloud account.
private final class MemoryStore: KeyValueStoring, @unchecked Sendable {
    private var values: [String: Data] = [:]

    init(_ values: [String: Data] = [:]) {
        self.values = values
    }

    func data(forKey key: String) -> Data? { values[key] }

    func setData(_ data: Data?, forKey key: String) {
        values[key] = data
    }
}

@MainActor
@Suite("Stay conditions store")
struct StayConditionsStoreTests {
    private let day: TimeInterval = 24 * 60 * 60
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func encoded(_ conditions: StayConditions) throws -> Data {
        try JSONEncoder().encode(conditions)
    }

    private func store(local: MemoryStore, cloud: MemoryStore? = nil) -> StayConditionsStore {
        StayConditionsStore(local: local, cloud: cloud, now: { [now] in now })
    }

    @Test("What was chosen is written to both stores")
    func writesToBoth() throws {
        let local = MemoryStore()
        let cloud = MemoryStore()
        let store = store(local: local, cloud: cloud)

        store.update(StayConditions(checkIn: now.addingTimeInterval(day), nights: 2, rooms: 2))

        let key = StayConditionsStore.key
        let fromLocal = try #require(local.data(forKey: key))
        let fromCloud = try #require(cloud.data(forKey: key))
        #expect(fromLocal == fromCloud)
        #expect(try JSONDecoder().decode(StayConditions.self, from: fromLocal).nights == 2)
    }

    @Test("iCloud is what a new launch reads, and defaults answer when it is empty")
    func cloudWinsOverLocal() throws {
        let local = MemoryStore([
            StayConditionsStore.key: try encoded(StayConditions(checkIn: now.addingTimeInterval(day), rooms: 1))
        ])
        let cloud = MemoryStore([
            StayConditionsStore.key: try encoded(StayConditions(checkIn: now.addingTimeInterval(day), rooms: 3))
        ])

        #expect(store(local: local, cloud: cloud).conditions.rooms == 3)
        #expect(store(local: local).conditions.rooms == 1)
        #expect(store(local: MemoryStore()).conditions == StayConditions())
    }

    @Test("A check-in date that has passed clears what was stored")
    func staleConditionsAreCleared() throws {
        let stale = StayConditions(checkIn: now.addingTimeInterval(-2 * day), nights: 3, rooms: 4)
        let local = MemoryStore([StayConditionsStore.key: try encoded(stale)])
        let cloud = MemoryStore([StayConditionsStore.key: try encoded(stale)])

        let store = store(local: local, cloud: cloud)

        #expect(store.conditions == StayConditions())
        // And it is gone from both, rather than being skipped over on every
        // launch from here on.
        #expect(local.data(forKey: StayConditionsStore.key) == nil)
        #expect(cloud.data(forKey: StayConditionsStore.key) == nil)
    }

    @Test("A stay starting earlier today is still today's")
    func todayIsNotStale() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let thisMorning = calendar.startOfDay(for: now)
        let local = MemoryStore([
            StayConditionsStore.key: try encoded(StayConditions(checkIn: thisMorning, nights: 5))
        ])

        #expect(store(local: local).conditions.nights == 5)
    }
}
