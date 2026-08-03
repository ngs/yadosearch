import SwiftUI
import YadoSearchCore

/// When, how long, how many — the inputs the plan search takes.
struct StayConditionsEditor: View {
    @Binding var stay: StayConditions

    /// Bridges the optional check-in date to `DatePicker`, which needs a value.
    /// "No date" means "whatever is on offer", and that is the default.
    private var checkInDate: Binding<Date> {
        Binding(
            get: { stay.checkIn ?? .now },
            set: { stay.checkIn = $0 }
        )
    }

    private var hasCheckInDate: Binding<Bool> {
        Binding(
            get: { stay.checkIn != nil },
            set: { stay.checkIn = $0 ? Date.now : nil }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("日付を指定", isOn: hasCheckInDate)
            if stay.checkIn != nil {
                DatePicker(
                    "チェックイン",
                    selection: checkInDate,
                    in: Date.now...,
                    displayedComponents: .date
                )
            }
            Stepper("\(stay.nights)泊", value: $stay.nights, in: 1...30)
            Stepper("\(stay.rooms)部屋", value: $stay.rooms, in: 1...10)
            GuestPartyEditor(party: $stay.party)
        }
        .font(.callout)
        .padding()
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
    }
}
