import SwiftUI
import YadoSearchCore

/// One bookable plan.
struct PlanRow: View {
    let plan: Plan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plan.name)
                .font(.headline)

            if let roomName = plan.roomName {
                Text(roomName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if let meal = plan.meal {
                    Text(meal)
                }
                if let checkIn = plan.checkIn, let checkOut = plan.checkOut {
                    Text("IN \(checkIn) / OUT \(checkOut)")
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)

            if !plan.facilities.isEmpty {
                Text(plan.facilities.joined(separator: "・"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let rate = plan.sampleRate {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(rate.formattedYen)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    if let rateType = plan.rateType {
                        Text(rateType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension Int {
    var formattedYen: String {
        formatted(.currency(code: "JPY").locale(Locale(identifier: "ja_JP")))
    }
}
