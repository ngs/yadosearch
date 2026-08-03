import SwiftUI
import YadoSearchPlatform

/// Finds a station to search around.
struct StationPickerView: View {
    let onChoose: (Station) -> Void

    @Environment(\.yadoSearch) private var yadoSearch
    @Environment(\.dismiss) private var dismiss
    @State private var model: StationSearchViewModel?
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if let model, !model.stations.isEmpty {
                    List(model.stations) { station in
                        Button {
                            onChoose(station)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(station.name)
                                if let subtitle = station.subtitle {
                                    Text(subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    placeholder
                }
            }
            .navigationTitle("駅をえらぶ")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .searchable(text: $query, prompt: "駅名")
            .onChange(of: query) { _, newValue in
                model?.search(newValue)
            }
        }
        .task {
            if model == nil {
                model = StationSearchViewModel(service: yadoSearch.stationSearch)
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if model?.isSearching == true {
            ProgressView()
        } else if let message = model?.errorMessage {
            ContentUnavailableView {
                Label("駅を検索できませんでした", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
        } else if model?.hasSearched == true {
            ContentUnavailableView.search(text: query)
        } else {
            ContentUnavailableView {
                Label("駅名を入力", systemImage: "tram")
            } description: {
                Text("「東京」「京都」のように駅名を入力すると候補が出ます。")
            }
        }
    }
}
