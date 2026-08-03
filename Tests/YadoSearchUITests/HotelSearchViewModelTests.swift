import Foundation
import Testing
import YadoSearchCore
@testable import YadoSearchUI

/// Serialized: the stub server holds one script at a time.
@Suite("Hotel search view model", .serialized)
@MainActor
struct HotelSearchViewModelTests {
    private let tokyoStation = GeoCoordinate(latitude: 35.681236, longitude: 139.767125)

    @Test("Loads the first page")
    func loadsFirstPage() async {
        StubJalanServer.install(
            StubJalanServer.Script(pages: [
                1: StubJalanServer.hotelResults(total: 45, displayFrom: 1, count: 30, firstID: 1)
            ])
        )
        let model = HotelSearchViewModel(
            client: StubJalanServer.client,
            target: .area(AreaSelection(prefectureID: "130000"))
        )

        await model.load()

        #expect(model.phase == .loaded)
        #expect(model.hotels.count == 30)
        #expect(model.numberOfResults == 45)
        #expect(model.canLoadMore)
    }

    @Test("Appends the next page when the tail appears")
    func pagesThroughResults() async {
        StubJalanServer.install(
            StubJalanServer.Script(pages: [
                1: StubJalanServer.hotelResults(total: 45, displayFrom: 1, count: 30, firstID: 1),
                31: StubJalanServer.hotelResults(total: 45, displayFrom: 31, count: 15, firstID: 31)
            ])
        )
        let model = HotelSearchViewModel(
            client: StubJalanServer.client,
            target: .area(AreaSelection(prefectureID: "130000"))
        )
        await model.load()

        let tail = model.hotels[model.hotels.count - 2]
        await model.loadMoreIfNeeded(currentItem: tail)

        #expect(model.hotels.count == 45)
        #expect(!model.canLoadMore)
        #expect(Set(model.hotels.map(\.id)).count == 45)
    }

    @Test("A row in the middle does not trigger a load")
    func doesNotPageFromTheMiddle() async {
        StubJalanServer.install(
            StubJalanServer.Script(pages: [
                1: StubJalanServer.hotelResults(total: 45, displayFrom: 1, count: 30, firstID: 1),
                31: StubJalanServer.hotelResults(total: 45, displayFrom: 31, count: 15, firstID: 31)
            ])
        )
        let model = HotelSearchViewModel(
            client: StubJalanServer.client,
            target: .area(AreaSelection(prefectureID: "130000"))
        )
        await model.load()

        await model.loadMoreIfNeeded(currentItem: model.hotels[0])

        #expect(model.hotels.count == 30)
    }

    /// A failure on the first page is the whole screen; a failure later is not.
    @Test("A failed first page becomes an error state")
    func reportsFirstPageFailure() async {
        StubJalanServer.install(StubJalanServer.Script(pages: [:], failingStarts: [1]))
        let model = HotelSearchViewModel(
            client: StubJalanServer.client,
            target: .name("テスト")
        )

        await model.load()

        #expect(model.phase == .failed("テスト用のエラーです。"))
        #expect(model.hotels.isEmpty)
    }

    @Test("A failed later page keeps the rows already shown")
    func keepsRowsWhenALaterPageFails() async {
        StubJalanServer.install(
            StubJalanServer.Script(
                pages: [1: StubJalanServer.hotelResults(total: 45, displayFrom: 1, count: 30, firstID: 1)],
                failingStarts: [31]
            )
        )
        let model = HotelSearchViewModel(
            client: StubJalanServer.client,
            target: .area(AreaSelection(prefectureID: "130000"))
        )
        await model.load()

        await model.loadMoreIfNeeded(currentItem: model.hotels[29])

        #expect(model.phase == .loaded)
        #expect(model.hotels.count == 30)
        #expect(!model.canLoadMore)
    }

    @Test("Distances are measured only for a proximity search")
    func measuresDistanceFromTheSearchCentre() async {
        StubJalanServer.install(
            StubJalanServer.Script(pages: [
                1: StubJalanServer.hotelResults(total: 3, displayFrom: 1, count: 3, firstID: 1)
            ])
        )
        let nearby = HotelSearchViewModel(
            client: StubJalanServer.client,
            target: .around(tokyoStation, radius: .aboutOneKilometre)
        )
        await nearby.load()

        let distances = nearby.hotels.compactMap { nearby.distance(to: $0) }
        #expect(distances.count == nearby.hotels.count)
        // The first inn sits on the search centre; each next one is ~45 m further.
        #expect(distances[0] < 20)
        #expect(distances[2] > distances[0])

        let byArea = HotelSearchViewModel(
            client: StubJalanServer.client,
            target: .area(AreaSelection(prefectureID: "130000"))
        )
        await byArea.load()

        #expect(byArea.searchCentre == nil)
        #expect(byArea.distance(to: byArea.hotels[0]) == nil)
    }
}
