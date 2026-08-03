import SwiftUI

/// A photo from jalan.net, with a placeholder that keeps its space.
///
/// Inn photos are optional and the ones that exist are slow — a plain
/// `AsyncImage` would collapse the row to nothing and then shove it open. This
/// reserves the shape up front so lists do not jump as they load.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder(symbol: "photo.badge.exclamationmark")
            case .empty:
                placeholder(symbol: "photo")
            @unknown default:
                placeholder(symbol: "photo")
            }
        }
    }

    private func placeholder(symbol: String) -> some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
    }
}
