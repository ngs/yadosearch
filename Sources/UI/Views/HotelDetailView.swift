import MapKit
import SwiftData
import SwiftUI
import YadoSearchCore
import YadoSearchPlatform

/// Everything known about one inn, and what it costs to stay there.
struct HotelDetailView: View {
    let hotel: Hotel

    @Environment(\.yadoSearch) private var yadoSearch
    @Environment(\.modelContext) private var modelContext
    @State private var model: HotelDetailViewModel?
    @State private var isFavorite = false

    private var shown: Hotel { model?.hotel ?? hotel }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let map = mapSection { map }
                factsSection
                if !shown.access.isEmpty { accessSection }
                if let caption = shown.caption { captionSection(caption) }
                plansSection
                bookingButton
            }
            .padding()
        }
        .navigationTitle(shown.name)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // The booking action lives in the toolbar and at the end of the page,
        // never as a pinned bottom bar. A `safeAreaInset(edge: .bottom)` here sits
        // on top of the floating tab bar and swallows its taps, which left the
        // tab bar dead for as long as this screen was open.
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isFavorite = StoredHotelStore.toggleFavorite(shown, in: modelContext)
                } label: {
                    Label(
                        isFavorite ? "お気に入りから削除" : "お気に入りに追加",
                        systemImage: isFavorite ? "heart.fill" : "heart"
                    )
                }
            }
            if let url = bookingURL {
                ToolbarItem(placement: .primaryAction) {
                    Link(destination: url) {
                        Label("じゃらんで予約", systemImage: "calendar.badge.plus")
                    }
                }
            }
        }
        .task {
            isFavorite = StoredHotelStore.contains(kind: .favorite, hotelID: hotel.id, in: modelContext)
            StoredHotelStore.recordVisit(hotel, in: modelContext)
            guard model == nil else { return }
            let model = HotelDetailViewModel(hotel: hotel, client: yadoSearch.client)
            self.model = model
            await model.load()
        }
    }

    /// The inn's page on jalan.net, carrying the stay being looked at and routed
    /// through the affiliate redirect.
    private var bookingURL: URL? {
        yadoSearch.affiliate.referralURL(hotelID: shown.id, stay: model?.stay)
    }
}

// MARK: - Sections

private extension HotelDetailView {
    var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if shown.pictureURL != nil {
                RemoteImage(url: shown.pictureURL)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 14))
            }
            if let catchCopy = shown.catchCopy {
                Text(catchCopy)
                    .font(.headline)
            }
            HStack(spacing: 10) {
                if let type = shown.type {
                    Text(type)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: .capsule)
                }
                if let rating = shown.rating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let count = shown.numberOfRatings {
                    Text("（\(count)件）")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    var mapSection: (some View)? {
        guard let coordinate = shown.coordinate else { return Optional<AnyView>.none }
        let point = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Map(initialPosition: .region(
                    MKCoordinateRegion(
                        center: point,
                        latitudinalMeters: 600,
                        longitudinalMeters: 600
                    )
                )) {
                    Marker(shown.name, systemImage: "bed.double.fill", coordinate: point)
                }
                .frame(height: 180)
                .clipShape(.rect(cornerRadius: 14))
                .allowsHitTesting(false)

                if let url = shown.mapsURL {
                    Link("マップで開く", destination: url)
                        .font(.footnote)
                }
            }
        )
    }

    var factsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("基本情報")
            LabeledContent("住所") {
                Text(shown.postCode.map { "〒\($0)\n\(shown.address)" } ?? shown.address)
                    .multilineTextAlignment(.trailing)
            }
            if let checkIn = shown.checkIn {
                LabeledContent("チェックイン", value: checkIn)
            }
            if let checkOut = shown.checkOut {
                LabeledContent("チェックアウト", value: checkOut)
            }
            if let area = shown.areaSummary {
                LabeledContent("エリア", value: area)
            }
        }
    }

    var accessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("アクセス")
            ForEach(shown.access) { access in
                VStack(alignment: .leading, spacing: 2) {
                    Text(access.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(access.detail)
                        .font(.callout)
                }
            }
        }
    }

    func captionSection(_ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("この宿について")
            Text(caption)
                .font(.callout)
        }
    }

    @ViewBuilder
    var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("宿泊プラン")
            if let model {
                StayConditionsEditor(stay: Binding(get: { model.stay }, set: { model.stay = $0 }))
                plans(model)
            }
        }
    }

    @ViewBuilder
    func plans(_ model: HotelDetailViewModel) -> some View {
        switch model.plansPhase {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case let .failed(message):
            // A plan search with nothing available answers with an error, so this
            // is an ordinary outcome rather than a fault worth alarming about.
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .loaded where model.plans.isEmpty:
            Text("この条件で予約できるプランは見つかりませんでした。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .loaded:
            ForEach(model.plans) { plan in
                // `bookingURL` is the plain jalan.net page; `detailURL` goes
                // through JwsRedirect and carries the API key, so it is only the
                // fallback and is not worth wrapping for affiliate credit.
                if let url = plan.bookingURL.map(yadoSearch.affiliate.referralURL(for:)) ?? plan.detailURL {
                    Link(destination: url) {
                        PlanRow(plan: plan)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                } else {
                    PlanRow(plan: plan)
                }
                Divider()
            }
        }
    }

    @ViewBuilder
    var bookingButton: some View {
        if let url = bookingURL {
            Link(destination: url) {
                Text("じゃらんで予約")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
    }

    func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
    }
}

private extension Hotel {
    /// Opens the inn in Maps. Built from the coordinate rather than the address,
    /// which Maps often cannot resolve for a Japanese street address.
    var mapsURL: URL? {
        guard let coordinate else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "q", value: name)
        ]
        return components?.url
    }
}
