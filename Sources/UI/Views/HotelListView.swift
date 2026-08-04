import SwiftUI
import YadoSearchCore

/// Results for one search, paged as the list is scrolled.
struct HotelListView: View {
    let search: SavedSearch
    /// What the detail column shows. Set by choosing a row; the row itself
    /// navigates nowhere, because the inn is not in this column.
    @Binding var selectedHotel: HotelReference?

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
                scope: search.scope,
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
            ProgressView("Searching…")
        case let .failed(message):
            ContentUnavailableView {
                Label("The search failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") {
                    Task { await model.load() }
                }
            }
        case .loaded where model.listings.isEmpty:
            ContentUnavailableView {
                Label("No inns found", systemImage: "bed.double")
            } description: {
                Text("Try again with different conditions.")
            }
        case .loaded:
            list(model)
        }
    }

    private func list(_ model: HotelSearchViewModel) -> some View {
        List {
            Section {
                ForEach(Array(model.listings.enumerated()), id: \.element.id) { index, listing in
                    if let reference = HotelReference(listing: listing) {
                        // A button rather than `List(selection:)`: the list is
                        // pushed inside the sidebar's stack, and a selection
                        // bound from there never reaches the detail column on
                        // the Mac — clicking a row simply did nothing.
                        Button {
                            selectedHotel = reference
                        } label: {
                            HotelRow(listing: listing, distance: model.distance(to: listing))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(rowBackground(for: reference))
                        .accessibilityIdentifier(YadoAccessibilityID.hotelRow(index))
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

    /// "Jalan 344, Rakuten Travel 1,271".
    ///
    /// What each site says it has for the query, counted before the same inn
    /// found on both is merged into one row. How many rows are *loaded* is not
    /// here: the list pages as it is scrolled, so that number is a fact about
    /// how far you have scrolled rather than about the search.
    /// The selected inn keeps a tint behind it, which is what `List(selection:)`
    /// drew for free and a button has to be told to draw.
    @ViewBuilder
    private func rowBackground(for reference: HotelReference) -> some View {
        if selectedHotel == reference {
            Color.accentColor.opacity(0.15)
        } else {
            Color.clear
        }
    }

    private func header(_ model: HotelSearchViewModel) -> String {
        let breakdown = Provider.allCases
            .compactMap { provider in
                model.totals[provider].map { total in
                    String(localized: "\(provider.title) \(total.formatted(.number))")
                }
            }
            .joined(separator: String(localized: ", "))
        return breakdown.isEmpty
            ? String(localized: "\(model.listings.count) shown")
            : breakdown
    }

    @ViewBuilder
    private func footer(_ model: HotelSearchViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // One site failing leaves the other's results on screen, so this is
            // a note under the list rather than an error state over it.
            ForEach(Provider.allCases) { provider in
                if let message = model.providerErrors[provider] {
                    Text("\(provider.title): \(message)")
                }
            }
            if model.filtersAppliedToJalanOnly {
                Text("Filters apply to the Jalan results only.")
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
