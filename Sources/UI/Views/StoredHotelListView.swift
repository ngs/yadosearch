import SwiftData
import SwiftUI
import YadoSearchPlatform

/// The favourites and history tabs — the same list over the same table, newest
/// first, differing only in wording and in whether clearing it wholesale makes
/// sense.
struct StoredHotelListView: View {
    let kind: StoredHotel.Kind
    /// What the detail column shows, shared with every other list.
    @Binding var selectedHotel: HotelReference?

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
                        Button("Delete all", role: .destructive) {
                            StoredHotelStore.clear(kind: .history, in: modelContext)
                        }
                    }
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
                let reference = HotelReference(provider: entry.provider, id: entry.hotelID)
                Button {
                    selectedHotel = reference
                } label: {
                    HotelRow(
                        name: entry.name,
                        area: entry.areaSummary,
                        catchCopy: entry.catchCopy,
                        pictureURL: entry.pictureURL
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(selectedHotel == reference ? Color.accentColor.opacity(0.15) : Color.clear)
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
        case .favorite: String(localized: "Favourites")
        case .history: String(localized: "History")
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
        case .favorite: String(localized: "No favourites yet")
        case .history: String(localized: "No inns viewed yet")
        }
    }

    var emptyDescription: String {
        switch self {
        case .favorite: String(localized: "Tap the heart on an inn's page and it will stay here.")
        case .history: String(localized: "Open an inn's page and it will stay here.")
        }
    }
}
