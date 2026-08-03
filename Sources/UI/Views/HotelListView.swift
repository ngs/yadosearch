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
        case .loaded where model.listings.isEmpty:
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
                ForEach(model.listings) { listing in
                    if let reference = HotelReference(listing: listing) {
                        NavigationLink(value: SearchRoute.hotel(reference)) {
                            HotelRow(listing: listing, distance: model.distance(to: listing))
                        }
                        .task {
                            await model.loadMoreIfNeeded(currentItem: listing)
                        }
                    }
                }
            } header: {
                // The per-provider totals are counted before the same inn found
                // on both sites is merged into one row, so they add up to more
                // than the list shows. Both numbers are true; neither alone is.
                Text(header(model))
            } footer: {
                footer(model)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await model.load()
        }
    }

    private func header(_ model: HotelSearchViewModel) -> String {
        let breakdown = Provider.allCases
            .compactMap { provider in
                model.totals[provider].map { "\(provider.title) \($0)" }
            }
            .joined(separator: " / ")
        return breakdown.isEmpty
            ? "\(model.listings.count)件"
            : "\(model.listings.count)件（\(breakdown)）"
    }

    @ViewBuilder
    private func footer(_ model: HotelSearchViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // One site failing leaves the other's results on screen, so this is
            // a note under the list rather than an error state over it.
            ForEach(Provider.allCases) { provider in
                if let message = model.providerErrors[provider] {
                    Text("\(provider.title)：\(message)")
                }
            }
            if model.filtersAppliedToJalanOnly {
                Text("絞り込み条件はじゃらんの結果にのみ反映されます。")
            }
            if model.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
    }
}
