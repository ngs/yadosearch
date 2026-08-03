import SwiftData
import SwiftUI
import YadoSearchPlatform

/// The favourites and history tabs — the same list over the same table, newest
/// first, differing only in wording and in whether clearing it wholesale makes
/// sense.
struct StoredHotelListView: View {
    let kind: StoredHotel.Kind

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredHotel.savedAt, order: .reverse) private var stored: [StoredHotel]

    private var entries: [StoredHotel] {
        stored.filter { $0.kindRawValue == kind.rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle(kind.title)
            .toolbar {
                if kind == .history, !entries.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("すべて削除", role: .destructive) {
                            StoredHotelStore.clear(kind: .history, in: modelContext)
                        }
                    }
                }
            }
            .navigationDestination(for: SearchRoute.self) { route in
                if case let .hotel(hotel) = route {
                    HotelDetailView(hotel: hotel)
                }
            }
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label(kind.emptyTitle, systemImage: kind.systemImage)
        } description: {
            Text(kind.emptyDescription)
        }
    }

    private var list: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink(value: SearchRoute.hotel(entry.hotel)) {
                    HotelRow(
                        name: entry.name,
                        area: entry.areaSummary,
                        catchCopy: entry.catchCopy,
                        pictureURL: entry.pictureURL
                    )
                }
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
    }

    private func delete(at offsets: IndexSet) {
        let entries = entries
        for index in offsets {
            modelContext.delete(entries[index])
        }
        try? modelContext.save()
    }
}

extension StoredHotel.Kind {
    var title: String {
        switch self {
        case .favorite: "お気に入り"
        case .history: "履歴"
        }
    }

    var systemImage: String {
        switch self {
        case .favorite: "heart"
        case .history: "clock"
        }
    }

    var emptyTitle: String {
        switch self {
        case .favorite: "お気に入りはまだありません"
        case .history: "見た宿はまだありません"
        }
    }

    var emptyDescription: String {
        switch self {
        case .favorite: "宿の詳細画面のハートを押すと、ここに残ります。"
        case .history: "宿の詳細画面を開くと、ここに残ります。"
        }
    }
}
