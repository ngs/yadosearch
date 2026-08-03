import SwiftUI
import YadoSearchCore

/// Results for one search, paged as the list is scrolled.
struct HotelListView: View {
    let search: SavedSearch

    @Environment(\.yadoSearch) private var yadoSearch
    @State private var model: HotelSearchViewModel?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(search.title)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard model == nil else { return }
            let model = HotelSearchViewModel(
                client: yadoSearch.client,
                target: search.target,
                filters: search.filters,
                party: search.party
            )
            self.model = model
            await model.load()
        }
    }

    @ViewBuilder
    private func content(_ model: HotelSearchViewModel) -> some View {
        switch model.phase {
        case .loading:
            ProgressView("さがしています…")
        case let .failed(message):
            ContentUnavailableView {
                Label("さがせませんでした", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("もう一度試す") {
                    Task { await model.load() }
                }
            }
        case .loaded where model.hotels.isEmpty:
            ContentUnavailableView {
                Label("宿が見つかりません", systemImage: "bed.double")
            } description: {
                Text("条件を変えてもう一度おためしください。")
            }
        case .loaded:
            list(model)
        }
    }

    private func list(_ model: HotelSearchViewModel) -> some View {
        List {
            Section {
                ForEach(model.hotels) { hotel in
                    NavigationLink(value: SearchRoute.hotel(hotel)) {
                        HotelRow(hotel: hotel, distance: model.distance(to: hotel))
                    }
                    .task {
                        await model.loadMoreIfNeeded(currentItem: hotel)
                    }
                }
            } header: {
                Text("\(model.numberOfResults)件")
            } footer: {
                if model.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if !model.canLoadMore, model.numberOfResults > model.hotels.count {
                    // The walk stopped early — a page failed. Say so, rather than
                    // letting the count and the list silently disagree.
                    Text("これ以上読み込めませんでした。")
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await model.load()
        }
    }
}
