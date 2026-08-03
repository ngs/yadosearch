import SwiftUI
import YadoSearchCore

/// One bookable plan.
struct PlanRow: View {
    let plan: StayPlan

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

            if let facilities = plan.facilities, !facilities.isEmpty {
                Text(facilities.joined(separator: "・"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // The total is the price of the stay as asked for; the sample rate
            // is Jalan's per-person guide, which is all there is when no date
            // was given. Rakuten quotes only the former.
            if let rate = plan.totalRate ?? plan.sampleRate {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(rate.formattedYen)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    if let rateType = plan.rateType ?? (plan.totalRate == nil ? nil : "合計") {
                        Text(rateType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if plan.partial == true {
                        Text("一部の日のみ")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
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
