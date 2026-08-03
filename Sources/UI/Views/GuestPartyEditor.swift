import SwiftUI
import YadoSearchCore

/// The four preschooler rows are Jalan's own breakdown, and they exist because
/// each one is priced differently. Showing them separately is what lets the
/// search return rooms the party can actually be charged for.
struct GuestPartyEditor: View {
    @Binding var party: GuestParty

    var body: some View {
        Stepper("大人 \(party.adults)名", value: $party.adults, in: 1...20)
        Stepper("小学生 \(party.elementarySchoolChildren)名", value: $party.elementarySchoolChildren, in: 0...10)
        Stepper(
            "幼児（布団・食事あり）\(party.preschoolersWithBedAndMeal)名",
            value: $party.preschoolersWithBedAndMeal,
            in: 0...10
        )
        Stepper(
            "幼児（食事のみ）\(party.preschoolersWithMealOnly)名",
            value: $party.preschoolersWithMealOnly,
            in: 0...10
        )
        Stepper(
            "幼児（布団のみ）\(party.preschoolersWithBedOnly)名",
            value: $party.preschoolersWithBedOnly,
            in: 0...10
        )
        Stepper(
            "幼児（布団・食事なし）\(party.preschoolersWithNeither)名",
            value: $party.preschoolersWithNeither,
            in: 0...10
        )
    }
}

extension GuestParty {
    /// "大人2名・子ども1名" — the one-line summary for a collapsed row.
    var summary: String {
        var parts = ["大人\(adults)名"]
        if childCount > 0 {
            parts.append("子ども\(childCount)名")
        }
        return parts.joined(separator: "・")
    }
}
