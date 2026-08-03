import SwiftData
import SwiftUI
import YadoSearchCore
import YadoSearchPlatform

/// The four ways to look for an inn, carried over from the original app:
/// by name, near you, by area, and around a station.
enum SearchMode: String, CaseIterable, Identifiable {
    case keyword
    case nearby
    case area
    case station

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyword: "キーワード"
        case .nearby: "現在地"
        case .area: "地域"
        case .station: "駅"
        }
    }

    var systemImage: String {
        switch self {
        case .keyword: "magnifyingglass"
        case .nearby: "location"
        case .area: "map"
        case .station: "tram"
        }
    }
}

/// An area the user picked, with the phrase to show for it.
struct ChosenArea: Hashable {
    var selection: AreaSelection
    var name: String
}

struct SearchView: View {
    @Environment(\.yadoSearch) private var yadoSearch
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredSearch.searchedAt, order: .reverse) private var recentSearches: [StoredSearch]

    @State private var mode: SearchMode = .keyword
    @State private var keyword = ""
    @State private var radius: SearchRadius = .aboutTwoAndAHalfKilometres
    @State private var location = CurrentLocationProvider()
    @State private var chosenArea: ChosenArea?
    @State private var chosenStation: Station?
    @State private var isPickingArea = false
    @State private var isPickingStation = false
    @State private var isEditingFilters = false
    @State private var path: [SearchRoute] = []
    // Kept across searches on purpose: someone who wants a 禁煙 room with a
    // 露天風呂 wants it for the next search too.
    @State private var filters = SearchFilters()
    @State private var party = GuestParty()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if yadoSearch.isConfigured {
                    form
                } else {
                    NotConfiguredView()
                }
            }
            .navigationTitle("宿さがし")
            .navigationDestination(for: SearchRoute.self) { route in
                switch route {
                case let .results(search):
                    HotelListView(search: search)
                case let .hotel(hotel):
                    HotelDetailView(hotel: hotel)
                }
            }
        }
        .sheet(isPresented: $isEditingFilters) {
            SearchFiltersView(filters: $filters, party: $party)
        }
        .sheet(isPresented: $isPickingArea) {
            AreaPickerView { chosen in
                chosenArea = chosen
            }
        }
        .sheet(isPresented: $isPickingStation) {
            StationPickerView { station in
                chosenStation = station
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                Picker("さがしかた", selection: $mode) {
                    ForEach(SearchMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            switch mode {
            case .keyword: keywordSection
            case .nearby: nearbySection
            case .area: areaSection
            case .station: stationSection
            }

            conditionsSection

            Section {
                Button {
                    if let search = currentSearch {
                        run(search)
                    }
                } label: {
                    Text("宿をさがす")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentSearch == nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            recentSearchesSection
        }
        .formStyle(.grouped)
    }

    /// What the search will be narrowed by, one line per condition that is
    /// actually in effect. Every row opens the same editing sheet — there is no
    /// separate "絞り込み" row to find first.
    private var conditionsSection: some View {
        Section("検索条件") {
            ForEach(conditionRows, id: \.title) { row in
                Button {
                    isEditingFilters = true
                } label: {
                    conditionLabel(title: row.title, value: row.value)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private struct ConditionRow {
        let title: String
        let value: String
    }

    /// The party is always shown — a search always has one — and the rest appear
    /// only once they are set, so the section stays short when nothing is.
    private var conditionRows: [ConditionRow] {
        var rows = [ConditionRow(title: "人数", value: party.summary)]
        if filters.sortOrder != .unspecified {
            rows.append(ConditionRow(title: "並び順", value: filters.sortOrder.title))
        }
        if let hotelType = filters.hotelType {
            rows.append(ConditionRow(title: "宿の種類", value: hotelType.title))
        }
        if let budget = filters.budgetSummary {
            rows.append(ConditionRow(title: "予算", value: budget))
        }
        if let amenities = filters.amenitySummary {
            rows.append(ConditionRow(title: "こだわり", value: amenities))
        }
        return rows
    }

    /// `contentShape` is what makes the whole row tappable. Without it a
    /// `.plain` button in a form only responds where the text actually is.
    private func conditionLabel(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var recentSearchesSection: some View {
        if !recentSearches.isEmpty {
            Section {
                ForEach(recentSearches) { entry in
                    if let search = entry.search {
                        Button {
                            run(search)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(search.title)
                                    .foregroundStyle(.primary)
                                if !search.conditionsSummary.isEmpty {
                                    Text(search.conditionsSummary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onDelete(perform: deleteRecentSearches)
            } header: {
                Text("最近の検索")
            } footer: {
                Button("履歴を消す", role: .destructive) {
                    SearchHistoryStore.clear(in: modelContext)
                }
                .font(.footnote)
            }
        }
    }

    private func deleteRecentSearches(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(recentSearches[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Per-mode sections

private extension SearchView {
    var keywordSection: some View {
        Section {
            TextField("宿名の一部", text: $keyword)
                .autocorrectionDisabled()
                #if !os(macOS)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                #endif
                .onSubmit {
                    if let search = currentSearch { run(search) }
                }
        } header: {
            Text("宿の名前")
        } footer: {
            // Worth saying up front: the service refuses rather than truncating,
            // and the error it returns is easy to read as a fault in the app.
            Text("宿名で検索します。該当が200件を超えると、じゃらん側が結果を返さずエラーになります。")
        }
    }

    var nearbySection: some View {
        Section {
            switch location.state {
            case .idle:
                Button("現在地を取得", systemImage: "location") {
                    location.requestLocation()
                }
            case .locating:
                HStack {
                    ProgressView()
                    Text("現在地を取得中…")
                        .foregroundStyle(.secondary)
                }
            case let .located(coordinate):
                LabeledContent("現在地") {
                    // The place name replaces the coordinate once the reverse
                    // geocoder answers; the degrees are what there is until then,
                    // and what remains if it never does.
                    Text(location.placeName ?? coordinate.formattedDegrees)
                        .multilineTextAlignment(.trailing)
                }
                Button("取得しなおす", systemImage: "arrow.clockwise") {
                    location.requestLocation()
                }
            case .denied:
                Label("位置情報の利用が許可されていません", systemImage: "location.slash")
                    .foregroundStyle(.secondary)
                Text("設定 App の「プライバシーとセキュリティ」から位置情報の利用を許可してください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .unavailable:
                Label("現在地を取得できませんでした", systemImage: "location.slash")
                    .foregroundStyle(.secondary)
                Button("もう一度試す", systemImage: "arrow.clockwise") {
                    location.requestLocation()
                }
            }
            radiusPicker
        } header: {
            Text("現在地のまわり")
        }
    }

    var areaSection: some View {
        Section {
            Button {
                isPickingArea = true
            } label: {
                pickerLabel(title: "地域", value: chosenArea?.name)
            }
            .buttonStyle(.plain)
        } header: {
            Text("地域から")
        } footer: {
            Text("広域 → 都道府県 → 大エリア → 小エリアの順に絞り込めます。")
        }
    }

    var stationSection: some View {
        Section {
            Button {
                isPickingStation = true
            } label: {
                pickerLabel(title: "駅", value: chosenStation?.name)
            }
            .buttonStyle(.plain)
            radiusPicker
        } header: {
            Text("駅のまわり")
        } footer: {
            // The API has no station parameter; this is what actually happens.
            Text("駅の位置を地図から調べ、そのまわりの宿をさがします。")
        }
    }

    /// A row that opens a picker sheet. Shaped like the condition rows, and made
    /// tappable across its whole width for the same reason.
    func pickerLabel(title: String, value: String?) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Text(value ?? "えらぶ")
                .foregroundStyle(value == nil ? .secondary : .primary)
                .multilineTextAlignment(.trailing)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    var radiusPicker: some View {
        Picker("さがす範囲", selection: $radius) {
            ForEach(SearchRadius.allCases) { radius in
                Text(radius.label).tag(radius)
            }
        }
    }
}

// MARK: - What the button does

private extension SearchView {
    /// `nil` while the current mode has nothing to search on, which is also what
    /// disables the button.
    var currentSearch: SavedSearch? {
        guard let (target, title) = targetAndTitle else { return nil }
        return SavedSearch(target: target, filters: filters, party: party, title: title)
    }

    /// Runs the search and remembers it. Recording here rather than on the
    /// results screen keeps a replayed search from re-recording itself on every
    /// back-and-forward.
    func run(_ search: SavedSearch) {
        SearchHistoryStore.record(search, in: modelContext)
        path.append(.results(search))
    }

    private var targetAndTitle: (SearchTarget, String)? {
        switch mode {
        case .keyword:
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return (.name(trimmed), "「\(trimmed)」")
        case .nearby:
            guard let coordinate = location.coordinate else { return nil }
            // The place name, when there is one, is what makes this search
            // recognisable in the recent list a week later.
            let origin = location.placeName ?? "現在地"
            return (.around(coordinate, radius: radius), "\(origin)から\(radius.label)")
        case .area:
            guard let chosenArea else { return nil }
            return (.area(chosenArea.selection), chosenArea.name)
        case .station:
            guard let chosenStation else { return nil }
            return (
                .around(chosenStation.coordinate, radius: radius),
                "\(chosenStation.name)から\(radius.label)"
            )
        }
    }
}

extension SearchRadius {
    var label: String {
        switch self {
        case .aboutOneKilometre: "約1km"
        case .aboutTwoAndAHalfKilometres: "約2.5km"
        case .aboutFiveKilometres: "約5km"
        case .aboutSevenKilometres: "約7km"
        case .aboutTenKilometres: "約10km"
        }
    }
}

extension GeoCoordinate {
    var formattedDegrees: String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }
}

#Preview {
    SearchView()
}
