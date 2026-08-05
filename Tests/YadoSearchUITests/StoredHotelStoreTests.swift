import Foundation
import SwiftData
import Testing
@testable import YadoSearchCore
@testable import YadoSearchPlatform

@Suite("Favourites and history")
@MainActor
struct StoredHotelStoreTests {
    private func makeContext() -> ModelContext {
        ModelContext(YadoSearchModelContainer.make(inMemory: true))
    }

    private func hotel(
        id: String = "300002",
        name: String = "ホテルテスト",
        provider: Provider = .jalan
    ) -> HotelProfile {
        HotelProfile(
            provider: provider,
            id: id,
            name: name,
            nameKana: nil,
            address: "東京都江東区常盤1-12-16",
            postalCode: nil,
            area: AreaNames(region: "首都圏", prefecture: "東京都", large: "江東", small: "江東"),
            kind: nil,
            catchCopy: "駅から近い",
            caption: nil,
            pictureURL: URL(string: "https://www.jalan.net/photo.jpg"),
            detailURL: nil,
            coordinate: GeoCoordinate(latitude: 35.6813, longitude: 139.7991),
            minimumCharge: nil,
            review: nil,
            access: nil,
            checkIn: nil,
            checkOut: nil,
            distanceMetres: nil,
            lastUpdate: nil,
            detail: nil
        )
    }

    private func all(in context: ModelContext) -> [StoredHotel] {
        (try? context.fetch(FetchDescriptor<StoredHotel>())) ?? []
    }

    @Test("Keeping an inn stores enough to render it offline")
    func storesASnapshot() throws {
        let context = makeContext()

        StoredHotelStore.add(hotel(), kind: .favorite, to: context)
        let saved = try #require(all(in: context).first)

        #expect(saved.hotelID == "300002")
        #expect(saved.kind == .favorite)
        #expect(saved.areaSummary == "東京都 · 江東")
        #expect(saved.pictureURL != nil)
        #expect(saved.coordinate?.latitude == 35.6813)
    }

    @Test("Keeping the same inn twice is a no-op")
    func doesNotDuplicate() {
        let context = makeContext()

        StoredHotelStore.add(hotel(), kind: .favorite, to: context)
        StoredHotelStore.add(hotel(), kind: .favorite, to: context)

        #expect(all(in: context).count == 1)
    }

    /// The two lists are one table, so an inn that is both favourited and
    /// visited has to be able to sit in both without colliding on the unique ID.
    @Test("An inn can be in both lists at once")
    func separatesTheTwoLists() {
        let context = makeContext()

        StoredHotelStore.add(hotel(), kind: .favorite, to: context)
        StoredHotelStore.recordVisit(hotel(), in: context)

        #expect(all(in: context).count == 2)
        #expect(StoredHotelStore.contains(kind: .favorite, provider: .jalan, hotelID: "300002", in: context))
        #expect(StoredHotelStore.contains(kind: .history, provider: .jalan, hotelID: "300002", in: context))
    }

    @Test("Toggling a favourite reports the state it moved to")
    func togglesBothWays() {
        let context = makeContext()

        #expect(StoredHotelStore.toggleFavorite(hotel(), in: context))
        #expect(StoredHotelStore.contains(kind: .favorite, provider: .jalan, hotelID: "300002", in: context))
        #expect(!StoredHotelStore.toggleFavorite(hotel(), in: context))
        #expect(all(in: context).isEmpty)
    }

    @Test("Revisiting an inn moves it back to the top instead of duplicating it")
    func revisitMovesToTop() throws {
        let context = makeContext()

        StoredHotelStore.recordVisit(hotel(id: "1", name: "一番目"), in: context)
        StoredHotelStore.recordVisit(hotel(id: "2", name: "二番目"), in: context)
        let firstVisit = try #require(all(in: context).first { $0.hotelID == "1" }).savedAt
        StoredHotelStore.recordVisit(hotel(id: "1", name: "一番目"), in: context)

        let entries = all(in: context)
        #expect(entries.count == 2)
        let revisited = try #require(entries.first { $0.hotelID == "1" })
        #expect(revisited.savedAt > firstVisit)
    }

    @Test("History is capped, oldest first out")
    func trimsHistory() throws {
        let context = makeContext()
        let limit = StoredHotelStore.historyLimit

        for index in 0..<(limit + 10) {
            StoredHotelStore.recordVisit(hotel(id: String(index), name: "宿\(index)"), in: context)
        }

        let entries = all(in: context)
        #expect(entries.count == limit)
        // The ten oldest are the ones that went.
        #expect(!entries.contains { $0.hotelID == "0" })
        #expect(entries.contains { $0.hotelID == String(limit + 9) })
    }

    @Test("Clearing one list leaves the other alone")
    func clearsOneList() {
        let context = makeContext()
        StoredHotelStore.add(hotel(), kind: .favorite, to: context)
        StoredHotelStore.recordVisit(hotel(), in: context)

        StoredHotelStore.clear(kind: .history, in: context)

        #expect(all(in: context).count == 1)
        #expect(StoredHotelStore.contains(kind: .favorite, provider: .jalan, hotelID: "300002", in: context))
    }

    @Test("A stored inn rebuilds into one the detail screen can show")
    func rebuildsHotel() throws {
        let context = makeContext()
        StoredHotelStore.add(hotel(), kind: .favorite, to: context)

        let stored = try #require(all(in: context).first)

        // Enough to reopen the inn on the right site, plus the snapshot the
        // list draws from.
        #expect(stored.reference == (.jalan, "300002"))
        #expect(stored.prefecture == "東京都")
        #expect(stored.coordinate == hotel().coordinate)
    }
}
