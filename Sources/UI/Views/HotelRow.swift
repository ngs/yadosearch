import SwiftUI
import YadoSearchCore

/// One inn in a results or favourites list.
struct HotelRow: View {
    let name: String
    let area: String?
    let catchCopy: String?
    let pictureURL: URL?
    /// Metres from the point the search was centred on, when there was one.
    var distance: Double?
    /// The sites this inn is carried by, in a stable order.
    var providers: [Provider] = []
    /// The cheapest of the quoted prices, when any provider quoted one.
    var lowestCharge: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImage(url: pictureURL)
                .frame(width: 88, height: 66)
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                    .lineLimit(2)

                if let catchCopy {
                    Text(catchCopy)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    if let area {
                        Text(area)
                    }
                    if let distance {
                        Label(distance.formattedDistance, systemImage: "location")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)

                HStack(spacing: 6) {
                    ForEach(providers) { provider in
                        Text(provider.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(provider.tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(provider.tint.opacity(0.15), in: .capsule)
                    }
                    if let lowestCharge {
                        Text("\(lowestCharge.formattedYen)〜")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension HotelRow {
    init(listing: HotelListing, distance: Double? = nil) {
        self.init(
            name: listing.name,
            area: listing.area?.summary,
            catchCopy: listing.catchCopy,
            pictureURL: listing.pictureURL,
            distance: distance,
            providers: listing.offers.map(\.provider),
            lowestCharge: listing.lowestCharge
        )
    }
}

extension AreaNames {
    /// "東京都・浅草" — the two levels that actually place an inn for a reader.
    var summary: String? {
        [prefecture, large]
            .compactMap { $0 }
            .joined(separator: "・")
            .nonEmptyText
    }
}

extension Provider {
    /// How each site names itself.
    var title: String {
        switch self {
        case .jalan: String(localized: "じゃらん")
        case .rakuten: String(localized: "楽天トラベル")
        }
    }

    /// Each site's own brand colour, sampled from its logo: じゃらん's orange and
    /// 楽天トラベル's green. The app's own accent is pink, so a badge in these
    /// reads as "which site", never as "selected".
    var tint: Color {
        switch self {
        case .jalan: Color(red: 0.929, green: 0.439, blue: 0.180)
        case .rakuten: Color(red: 0.325, green: 0.714, blue: 0.208)
        }
    }
}

extension Double {
    /// Metres under a kilometre, kilometres above it.
    var formattedDistance: String {
        self < 1_000
            ? "\(Int(rounded()))m"
            : String(format: "%.1fkm", self / 1_000)
    }
}

extension String {
    var nonEmptyText: String? {
        isEmpty ? nil : self
    }
}
