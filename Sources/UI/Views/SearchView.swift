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
        case .keyword: String(localized: "Name")
        case .nearby: String(localized: "Nearby")
        case .area: String(localized: "Area")
        case .station: String(localized: "Station")
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
///
/// The target rather than a selection, because the two providers' selections
/// are different types — which one this is decides which site the search
/// reaches, and there is nothing to translate between them.
struct ChosenArea: Hashable {
    var target: SearchTarget
    var name: String
}

struct SearchView: View {
    /// The inn the detail column is showing. Handed down to the results list,
    /// which is what sets it.
    @Binding var selectedHotel: HotelReference?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredSearch.searchedAt, order: .reverse) private var recentSearches: [StoredSearch]

    @State private var mode: SearchMode = .keyword
    @State private var keyword = ""
    @State private var radius: SearchRadius = .aboutTwoAndAHalfKilometres
    @State private var location = CurrentLocationProvider()
    @State private var chosenArea: ChosenArea?
    @State private var chosenStation: Station?
    @State private var isPickingArea = false
    @State private var isPickingScope = false
    @State private var isPickingStation = false
    @State private var isEditingFilters = false
    /// Typed, and it has to be: a `NavigationPath` in this position renders
    /// nothing at all on the Mac — the title and the back button appear and the
    /// destination never draws. The crash it was introduced to fix
    /// (`AnyNavigationPath.Error.comparisonTypeMismatch` on iPhone, when a
    /// recent search was run while an inn was open) is answered by clearing the
    /// selected inn before pushing instead.
    @State private var path: [SearchRoute] = []
    /// Which sites to ask. An area search cannot ask both, so this is coerced
    /// to one provider whenever the area mode is showing.
    @State private var scope: SearchScope = .both
    // Kept across searches on purpose: someone who wants a 禁煙 room with a
    // 露天風呂 wants it for the next search too.
    @State private var filters = SearchFilters()
    @State private var party = GuestParty()

    var body: some View {
        NavigationStack(path: $path) {
            form
                .navigationTitle("YadoSearch")
                .task {
                    // Twins arrive by sync rather than by use, so the list is
                    // tidied when it is shown rather than only when it is
                    // written to.
                    SearchHistoryStore.deduplicate(in: modelContext)
                }
                .navigationDestination(for: SearchRoute.self) { route in
                    switch route {
                    case let .results(search):
                        HotelListView(search: search, selectedHotel: $selectedHotel)
                    }
                }
                #if !os(macOS)
                // Choosing a row sets the item and the stack pushes the inn;
                // popping clears it. On the Mac the same binding fills the
                // window's detail column instead, so no destination there.
                .navigationDestination(item: $selectedHotel) { hotel in
                    HotelDetailView(reference: hotel)
                }
                #endif
        }
        .sheet(isPresented: $isEditingFilters) {
            SearchFiltersView(filters: $filters, party: $party)
                .sheetSize()
        }
        .sheet(isPresented: $isPickingArea) {
            // Which tree to show follows from the site already chosen; there is
            // no picker that spans both, because the two schemes share no codes.
            Group {
                if scope == .rakuten {
                    RakutenAreaPickerView { chosen in
                        chosenArea = chosen
                    }
                } else {
                    AreaPickerView { chosen in
                        chosenArea = chosen
                    }
                }
            }
            .sheetSize()
        }
        .sheet(isPresented: $isPickingScope) {
            SearchScopePicker(scope: $scope, allowsBoth: mode != .area)
                .sheetSize()
        }
        .sheet(isPresented: $isPickingStation) {
            StationPickerView { station in
                chosenStation = station
            }
            .sheetSize()
        }
    }

    private var form: some View {
        Form {
            Section {
                Picker("How to search", selection: $mode) {
                    ForEach(SearchMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            scopeSection

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
                    Text("Find inns")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .accessibilityIdentifier(YadoAccessibilityID.searchSubmit)
                .buttonStyle(.borderedProminent)
                .disabled(currentSearch == nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            recentSearchesSection
        }
        .formStyle(.grouped)
        // The name field is near the top and the keyboard covers the conditions
        // and the search button, so scrolling has to be able to put it away —
        // the keyboard's own key runs the search rather than dismissing it.
        .scrollDismissesKeyboard(.immediately)
        .onChange(of: mode) { _, mode in
            // "両方" is not on offer for an area search, so entering that mode
            // has to land somewhere real — otherwise the segmented control has
            // a selection that is not one of its segments. Jalan, because its
            // hierarchy is the one that can be searched at any level.
            if mode == .area, scope == .both {
                scope = .jalan
            }
        }
    }

    /// Which sites to search. Three choices normally; two when an area is being
    /// picked, because an area code belongs to one scheme and there is nothing
    /// to send the other site.
    private var scopeSection: some View {
        Section {
            Button {
                isPickingScope = true
            } label: {
                pickerLabel(title: String(localized: "Search on"), value: scope.title)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(YadoAccessibilityID.searchScope)
        } header: {
            Text("Search on")
        } footer: {
            Text(scopeFooter)
        }
        .onChange(of: scope) { _, _ in
            // The area picked belongs to the site it was picked on, so switching
            // sites has to throw it away rather than carry a code the other site
            // cannot read.
            chosenArea = nil
        }
    }

    private var scopeFooter: String {
        if mode == .area {
            return String(localized: "The two sites divide the country differently and their codes cannot be converted, so an area search picks one of them.")
        }
        switch scope {
        case .both:
            return String(localized: "Searches both and merges an inn found on each into one row.")
        case .jalan, .rakuten:
            return String(localized: "Searches \(scope.title) only.")
        }
    }

    /// What the search will be narrowed by, one line per condition that is
    /// actually in effect. Every row opens the same editing sheet — there is no
    /// separate "絞り込み" row to find first.
    private var conditionsSection: some View {
        Section("Conditions") {
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
        var rows = [ConditionRow(title: "Guests", value: party.summary)]
        if filters.sortOrder != .unspecified {
            rows.append(ConditionRow(title: "Sort by", value: filters.sortOrder.title))
        }
        if let hotelType = filters.hotelType {
            rows.append(ConditionRow(title: "Property type", value: hotelType.title))
        }
        if let budget = filters.budgetSummary {
            rows.append(ConditionRow(title: "Budget", value: budget))
        }
        if let amenities = filters.amenitySummary {
            rows.append(ConditionRow(title: "Amenities", value: amenities))
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
                Text("Recent searches")
            } footer: {
                Button("Clear history", role: .destructive) {
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
            TextField("Part of the name", text: $keyword)
                .accessibilityIdentifier(YadoAccessibilityID.searchKeyword)
                .autocorrectionDisabled()
                #if !os(macOS)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                #endif
                .onSubmit {
                    if let search = currentSearch { run(search) }
                }
        } header: {
            Text("Inn name")
        } footer: {
            // Worth saying up front: the service refuses rather than truncating,
            // and the error it returns is easy to read as a fault in the app.
            Text("Searches by inn name. Jalan returns an error rather than a list when more than 200 inns match.")
        }
    }

    var nearbySection: some View {
        Section {
            switch location.state {
            case .idle:
                Button("Get my location", systemImage: "location") {
                    location.requestLocation()
                }
            case .locating:
                HStack {
                    ProgressView()
                    Text("Getting your location…")
                        .foregroundStyle(.secondary)
                }
            case let .located(coordinate):
                LabeledContent("Nearby") {
                    // The place name replaces the coordinate once the reverse
                    // geocoder answers; the degrees are what there is until then,
                    // and what remains if it never does.
                    Text(location.placeName ?? coordinate.formattedDegrees)
                        .multilineTextAlignment(.trailing)
                }
                Button("Get it again", systemImage: "arrow.clockwise") {
                    location.requestLocation()
                }
            case .denied:
                Label("Location access is off", systemImage: "location.slash")
                    .foregroundStyle(.secondary)
                Text("Allow location access in Settings, under Privacy & Security.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .unavailable:
                Label("Could not get your location", systemImage: "location.slash")
                    .foregroundStyle(.secondary)
                Button("Try again", systemImage: "arrow.clockwise") {
                    location.requestLocation()
                }
            }
            radiusPicker
        } header: {
            Text("Around you")
        }
    }

    var areaSection: some View {
        Section {
            Button {
                isPickingArea = true
            } label: {
                pickerLabel(title: "Area", value: chosenArea?.name)
            }
            .buttonStyle(.plain)
        } header: {
            Text("By area")
        } footer: {
            // The two hierarchies are not the same depth or the same cut, and
            // Rakuten's cannot be searched above its small class, so what can be
            // picked genuinely differs between them.
            if scope == .rakuten {
                Text("Narrow by prefecture, then by area. Rakuten Travel cannot search a whole prefecture.")
            } else {
                Text("Narrow down from region to prefecture to large area to small area.")
            }
        }
    }

    var stationSection: some View {
        Section {
            Button {
                isPickingStation = true
            } label: {
                pickerLabel(title: "Station", value: chosenStation?.name)
            }
            .buttonStyle(.plain)
            radiusPicker
        } header: {
            Text("Around a station")
        } footer: {
            // The API has no station parameter; this is what actually happens.
            Text("Finds the station on the map and looks for inns around it.")
        }
    }

    /// A row that opens a picker sheet. Shaped like the condition rows, and made
    /// tappable across its whole width for the same reason.
    func pickerLabel(title: String, value: String?) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Text(value ?? "Choose")
                .foregroundStyle(value == nil ? .secondary : .primary)
                .multilineTextAlignment(.trailing)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    var radiusPicker: some View {
        Picker("Distance", selection: $radius) {
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
        return SavedSearch(target: target, scope: scope, filters: filters, party: party, title: title)
    }

    /// Runs the search and remembers it. Recording here rather than on the
    /// results screen keeps a replayed search from re-recording itself on every
    /// back-and-forward.
    func run(_ search: SavedSearch) {
        SearchHistoryStore.record(search, in: modelContext)
        // The inn on the right belongs to the search being left behind.
        selectedHotel = nil
        path.append(.results(search))
    }

    private var targetAndTitle: (SearchTarget, String)? {
        switch mode {
        case .keyword:
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return (.name(trimmed), String(localized: "“\(trimmed)”"))
        case .nearby:
            guard let coordinate = location.coordinate else { return nil }
            // The place name, when there is one, is what makes this search
            // recognisable in the recent list a week later.
            let origin = location.placeName ?? String(localized: "Nearby")
            return (.around(coordinate, radius: radius), String(localized: "\(origin), \(radius.label)"))
        case .area:
            guard let chosenArea else { return nil }
            return (chosenArea.target, chosenArea.name)
        case .station:
            guard let chosenStation else { return nil }
            return (
                .around(chosenStation.coordinate, radius: radius),
                String(localized: "\(chosenStation.name), \(radius.label)")
            )
        }
    }
}

extension SearchRadius {
    var label: String {
        switch self {
        case .aboutOneKilometre: String(localized: "about 1km")
        case .aboutTwoAndAHalfKilometres: String(localized: "about 2.5km")
        case .aboutFiveKilometres: String(localized: "about 5km")
        case .aboutSevenKilometres: String(localized: "about 7km")
        case .aboutTenKilometres: String(localized: "about 10km")
        }
    }
}

extension GeoCoordinate {
    var formattedDegrees: String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }
}

#Preview {
    SearchView(selectedHotel: .constant(nil))
}
