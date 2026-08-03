import SwiftUI
import YadoSearchCore

/// The narrowing sheet: sort, inn type, budget, party and the whole amenity
/// vocabulary, grouped the way the 2010 release grouped it.
struct SearchFiltersView: View {
    @Binding var filters: SearchFilters
    @Binding var party: GuestParty

    @Environment(\.dismiss) private var dismiss

    private var minimumRate: Binding<Int> {
        Binding(get: { filters.minimumRate ?? 0 }, set: { filters.minimumRate = $0 == 0 ? nil : $0 })
    }

    private var maximumRate: Binding<Int> {
        Binding(get: { filters.maximumRate ?? 0 }, set: { filters.maximumRate = $0 == 0 ? nil : $0 })
    }

    private var hotelType: Binding<Int> {
        Binding(
            get: { filters.hotelType?.rawValue ?? 0 },
            set: { filters.hotelType = HotelType(rawValue: $0) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort by") {
                    Picker("Sort by", selection: $filters.sortOrder) {
                        ForEach(HotelSortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                }

                Section("Property type") {
                    Picker("Property type", selection: hotelType) {
                        Text("Any").tag(0)
                        ForEach(HotelType.allCases) { type in
                            Text(type.title).tag(type.rawValue)
                        }
                    }
                }

                Section {
                    Picker("From", selection: minimumRate) {
                        Text("No minimum").tag(0)
                        ForEach(SearchFilters.rateSteps, id: \.self) { rate in
                            Text(rate.formattedYen).tag(rate)
                        }
                    }
                    Picker("To", selection: maximumRate) {
                        Text("No maximum").tag(0)
                        ForEach(SearchFilters.rateSteps, id: \.self) { rate in
                            Text(rate.formattedYen).tag(rate)
                        }
                    }
                } header: {
                    Text("Budget (per person, per night)")
                }

                Section("Guests") {
                    GuestPartyEditor(party: $party)
                }

                ForEach(Amenity.Group.allCases) { group in
                    Section(group.title) {
                        ForEach(group.amenities) { amenity in
                            Toggle(amenity.title, isOn: binding(for: amenity))
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Filters")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear all") { filters.reset() }
                        .disabled(filters.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func binding(for amenity: Amenity) -> Binding<Bool> {
        Binding(
            get: { filters.amenities.contains(amenity) },
            set: { isOn in
                if isOn {
                    filters.amenities.insert(amenity)
                } else {
                    filters.amenities.remove(amenity)
                }
            }
        )
    }
}
