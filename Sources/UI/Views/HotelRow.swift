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
            }
        }
        .padding(.vertical, 4)
    }
}

extension HotelRow {
    init(hotel: Hotel, distance: Double? = nil) {
        self.init(
            name: hotel.name,
            area: hotel.areaSummary,
            catchCopy: hotel.catchCopy,
            pictureURL: hotel.pictureURL,
            distance: distance
        )
    }
}

extension Hotel {
    /// "東京都・浅草" — the two levels that actually place an inn for a reader.
    var areaSummary: String? {
        [area.prefecture, area.largeArea]
            .compactMap { $0 }
            .joined(separator: "・")
            .nonEmptyText
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
