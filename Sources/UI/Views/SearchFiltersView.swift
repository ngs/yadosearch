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
                Section("並び順") {
                    Picker("並び順", selection: $filters.sortOrder) {
                        ForEach(HotelSortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                }

                Section("宿の種類") {
                    Picker("宿の種類", selection: hotelType) {
                        Text("指定なし").tag(0)
                        ForEach(HotelType.allCases) { type in
                            Text(type.title).tag(type.rawValue)
                        }
                    }
                }

                Section {
                    Picker("下限", selection: minimumRate) {
                        Text("下限なし").tag(0)
                        ForEach(SearchFilters.rateSteps, id: \.self) { rate in
                            Text(rate.formattedYen).tag(rate)
                        }
                    }
                    Picker("上限", selection: maximumRate) {
                        Text("上限なし").tag(0)
                        ForEach(SearchFilters.rateSteps, id: \.self) { rate in
                            Text(rate.formattedYen).tag(rate)
                        }
                    }
                } header: {
                    Text("予算（1名1泊あたり）")
                }

                Section("人数") {
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
            .navigationTitle("絞り込み")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("すべて解除") { filters.reset() }
                        .disabled(filters.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
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
