import SwiftUI
import YadoSearchCore

/// Drills down 都道府県 → 小区分 → 細区分 in Rakuten's classification.
///
/// It looks shallower than the Jalan picker on purpose, and it is: the whole
/// country hangs off one 大区分 (`japan`), so showing that level would be a list
/// of one. What is left is 47 middle classes, which read as prefectures.
///
/// **Only the bottom of the tree can be searched.** Rakuten refuses a query
/// that stops above the small class, and refuses a small class that has detail
/// classes unless one is named, so there is no "◯◯全体でさがす" here — the
/// counterpart of "東京都全体" does not exist on this side.
struct RakutenAreaPickerView: View {
    let onChoose: (ChosenArea) -> Void

    @Environment(\.yadoSearch) private var yadoSearch
    @Environment(\.dismiss) private var dismiss
    @State private var model: RakutenAreaPickerViewModel?

    /// A middle class carries its large class along, because Rakuten wants the
    /// whole path and not just the leaf.
    private struct Level: Hashable {
        let largeClassID: String
        let middleClass: RakutenAreaTree.MiddleClass
    }

    private struct DetailLevel: Hashable {
        let largeClassID: String
        let middleClassID: String
        let smallClass: RakutenAreaTree.SmallClass
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model?.phase {
                case .loaded:
                    middleClassList
                case let .failed(message):
                    ContentUnavailableView {
                        Label("Could not load the areas", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try again") {
                            Task { await model?.load() }
                        }
                    }
                case .loading, .none:
                    ProgressView("Loading areas…")
                }
            }
            .navigationTitle("Choose an area")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: Level.self, destination: smallClassList(for:))
            .navigationDestination(for: DetailLevel.self, destination: detailClassList(for:))
        }
        .task {
            if model == nil {
                model = RakutenAreaPickerViewModel(catalog: yadoSearch.areaCatalog)
            }
            await model?.load()
        }
    }

    private var middleClassList: some View {
        List {
            ForEach(model?.tree.largeClasses ?? []) { large in
                ForEach(large.middleClasses) { middle in
                    NavigationLink(
                        middle.name,
                        value: Level(largeClassID: large.id, middleClass: middle)
                    )
                }
            }
        }
    }

    private func smallClassList(for level: Level) -> some View {
        List(level.middleClass.smallClasses) { small in
            if small.isSearchable {
                chooseButton(
                    ChosenArea(
                        target: .rakutenArea(RakutenAreaSelection(
                            largeClassCode: level.largeClassID,
                            middleClassCode: level.middleClass.id,
                            smallClassCode: small.id
                        )),
                        name: small.name
                    ),
                    title: small.name
                )
            } else {
                NavigationLink(
                    small.name,
                    value: DetailLevel(
                        largeClassID: level.largeClassID,
                        middleClassID: level.middleClass.id,
                        smallClass: small
                    )
                )
            }
        }
        .navigationTitle(level.middleClass.name)
    }

    private func detailClassList(for level: DetailLevel) -> some View {
        List(level.smallClass.detailClasses) { detail in
            chooseButton(
                ChosenArea(
                    target: .rakutenArea(RakutenAreaSelection(
                        largeClassCode: level.largeClassID,
                        middleClassCode: level.middleClassID,
                        smallClassCode: level.smallClass.id,
                        detailClassCode: detail.id
                    )),
                    name: detail.name
                ),
                title: detail.name
            )
        }
        .navigationTitle(level.smallClass.name)
    }

    private func chooseButton(_ area: ChosenArea, title: String) -> some View {
        // An area name, which the service only ever sends in Japanese.
        Button {
            onChoose(area)
            dismiss()
        } label: {
            Text(verbatim: title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
