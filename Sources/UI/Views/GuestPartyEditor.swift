import SwiftUI
import YadoSearchCore

/// The four preschooler rows are Jalan's own breakdown, and they exist because
/// each one is priced differently. Showing them separately is what lets the
/// search return rooms the party can actually be charged for.
struct GuestPartyEditor: View {
    @Binding var party: GuestParty

    var body: some View {
        Stepper("Adults: \(party.adults)", value: $party.adults, in: 1...20)
        Stepper("Primary school children: \(party.elementarySchoolChildren)", value: $party.elementarySchoolChildren, in: 0...10)
        Stepper(
            "Preschoolers, bed and meals: \(party.preschoolersWithBedAndMeal)",
            value: $party.preschoolersWithBedAndMeal,
            in: 0...10
        )
        Stepper(
            "Preschoolers, meals only: \(party.preschoolersWithMealOnly)",
            value: $party.preschoolersWithMealOnly,
            in: 0...10
        )
        Stepper(
            "Preschoolers, bed only: \(party.preschoolersWithBedOnly)",
            value: $party.preschoolersWithBedOnly,
            in: 0...10
        )
        Stepper(
            "Preschoolers, neither: \(party.preschoolersWithNeither)",
            value: $party.preschoolersWithNeither,
            in: 0...10
        )
    }
}

extension GuestParty {
    /// "大人2名・子ども1名" — the one-line summary for a collapsed row.
    var summary: String {
        var parts = [String(localized: "\(adults) adults")]
        if childCount > 0 {
            parts.append(String(localized: "\(childCount) children"))
        }
        return parts.joined(separator: String(localized: " · "))
    }
}
