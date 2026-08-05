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
            #if !os(macOS)
            // A value push, like the search tab's: the row is a
            // `NavigationLink` and this is its destination. On the Mac a row
            // *selects* instead, and the window's detail column renders it.
            .navigationDestination(for: HotelReference.self) { hotel in
                HotelDetailView(reference: hotel)
            }
            #endif
            .toolbar {
                #if !os(macOS)
                if !entries.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        EditButton()
                    }
                }
                #endif
                if kind == .history, !entries.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
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
                row(for: entry)
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
    }

    /// One row. Pushed on the iPhone, selected on the Mac and the iPad — the
    /// same split as the results list, and for the same reasons.
    @ViewBuilder
    private func row(for entry: StoredHotel) -> some View {
        let reference = HotelReference(provider: entry.provider, id: entry.hotelID)
        if hotelOpensInDetailColumn {
            Button {
                selectedHotel = reference
            } label: {
                storedRow(for: entry)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(selectedHotel == reference ? Color.accentColor.opacity(0.15) : Color.clear)
        } else {
            NavigationLink(value: reference) {
                storedRow(for: entry)
            }
        }
    }

    private func storedRow(for entry: StoredHotel) -> some View {
        HotelRow(
            name: entry.name,
            area: entry.areaSummary,
            catchCopy: entry.catchCopy,
            pictureURL: entry.pictureURL
        )
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
