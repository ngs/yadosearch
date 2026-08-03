import SwiftUI
import YadoSearchCore

/// Drills down 広域 → 都道府県 → 大エリア → 小エリア.
///
/// Every level is choosable, not just the deepest one: "北海道" is as reasonable
/// a search as "ススキノ・大通", and the API takes a code from any of the four.
struct AreaPickerView: View {
    let onChoose: (ChosenArea) -> Void

    @Environment(\.yadoSearch) private var yadoSearch
    @Environment(\.dismiss) private var dismiss
    @State private var model: AreaPickerViewModel?

    private enum Level: Hashable {
        case prefectures(AreaTree.Region)
        case largeAreas(AreaTree.Region, AreaTree.Prefecture)
        case smallAreas(AreaTree.Region, AreaTree.Prefecture, AreaTree.LargeArea)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model?.phase {
                case .loaded:
                    regionList
                case let .failed(message):
                    ContentUnavailableView {
                        Label("地域を読み込めませんでした", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("もう一度試す") {
                            Task { await model?.load() }
                        }
                    }
                case .loading, .none:
                    ProgressView("地域を読み込み中…")
                }
            }
            .navigationTitle("地域をえらぶ")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .navigationDestination(for: Level.self, destination: destination(for:))
        }
        .task {
            if model == nil {
                model = AreaPickerViewModel(catalog: yadoSearch.areaCatalog)
            }
            await model?.load()
        }
    }

    private var regionList: some View {
        List(model?.tree.regions ?? []) { region in
            NavigationLink(region.name, value: Level.prefectures(region))
        }
    }

    @ViewBuilder
    private func destination(for level: Level) -> some View {
        switch level {
        case let .prefectures(region):
            list(
                title: region.name,
                whole: ChosenArea(
                    target: .area(AreaSelection(regionID: region.id)),
                    name: region.name
                ),
                rows: region.prefectures.map {
                    Row(id: $0.id, name: $0.name, level: .largeAreas(region, $0))
                }
            )
        case let .largeAreas(region, prefecture):
            list(
                title: prefecture.name,
                whole: ChosenArea(
                    target: .area(AreaSelection(regionID: region.id, prefectureID: prefecture.id)),
                    name: prefecture.name
                ),
                rows: prefecture.largeAreas.map {
                    Row(id: $0.id, name: $0.name, level: .smallAreas(region, prefecture, $0))
                }
            )
        case let .smallAreas(region, prefecture, largeArea):
            List {
                Section {
                    chooseButton(
                        ChosenArea(
                            target: .area(AreaSelection(
                                regionID: region.id,
                                prefectureID: prefecture.id,
                                largeAreaID: largeArea.id
                            )),
                            name: largeArea.name
                        ),
                        title: String(localized: "\(largeArea.name)全体でさがす")
                    )
                }
                Section("小エリア") {
                    ForEach(largeArea.smallAreas) { smallArea in
                        chooseButton(
                            ChosenArea(
                                target: .area(AreaSelection(
                                    regionID: region.id,
                                    prefectureID: prefecture.id,
                                    largeAreaID: largeArea.id,
                                    smallAreaID: smallArea.id
                                )),
                                name: smallArea.name
                            ),
                            title: smallArea.name
                        )
                    }
                }
            }
            .navigationTitle(largeArea.name)
        }
    }

    /// One row of a level list: what to show, and where it leads.
    private struct Row: Identifiable {
        let id: String
        let name: String
        let level: Level
    }

    private func list(title: String, whole: ChosenArea, rows: [Row]) -> some View {
        List {
            Section {
                chooseButton(whole, title: String(localized: "\(title)全体でさがす"))
            }
            Section {
                ForEach(rows) { row in
                    NavigationLink(row.name, value: row.level)
                }
            }
        }
        .navigationTitle(title)
    }

    private func chooseButton(_ area: ChosenArea, title: String) -> some View {
        // Already localised by the caller, which builds it around an area name.
        Button {
            onChoose(area)
            dismiss()
        } label: {
            Text(verbatim: title)
        }
    }
}
