import MapKit
import SwiftData
import SwiftUI
import YadoSearchCore
import YadoSearchPlatform

/// Everything known about one inn, and what it costs to stay there.
///
/// The inn is one place, but it is sold by up to two sites, and the price, the
/// plans and the booking link all belong to whichever one is selected. The
/// segmented control at the top is that selection; switching it re-runs the
/// plan search against the other site.
struct HotelDetailView: View {
    let reference: HotelReference

    @Environment(\.yadoSearch) private var yadoSearch
    @Environment(\.modelContext) private var modelContext
    @State private var model: HotelDetailViewModel?
    @State private var isFavorite = false
    private let stayConditions = StayConditionsStore.shared

    private var name: String {
        model?.profile?.name ?? model?.listing?.name ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let model {
                    providerPicker(model)
                    header(model)
                    if let map = mapSection(model) { map }
                    factsSection(model)
                    accessSection(model)
                    captionSection(model)
                    plansSection(model)
                    bookingButton(model)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle(name)
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
                    guard let profile = model?.profile else { return }
                    isFavorite = StoredHotelStore.toggleFavorite(profile, in: modelContext)
                } label: {
                    Label(
                        isFavorite ? "Remove from favourites" : "Add to favourites",
                        systemImage: isFavorite ? "heart.fill" : "heart"
                    )
                }
                .accessibilityIdentifier(YadoAccessibilityID.hotelFavorite)
                .disabled(model?.profile == nil)
            }
            if let url = model?.bookingURL {
                ToolbarItem(placement: .primaryAction) {
                    SafariLink(destination: url) {
                        Label("Book", systemImage: "calendar.badge.plus")
                    }
                }
            }
        }
        .task {
            guard model == nil else { return }
            // The conditions are the ones last used, on this device or another,
            // unless their date has passed — see `StayConditionsStore`.
            stayConditions.refresh()
            let model = HotelDetailViewModel(
                provider: reference.provider,
                listing: reference.listing,
                client: yadoSearch.client,
                stay: stayConditions.conditions
            )
            self.model = model
            await model.load()
            refreshFavorite(model)
            if let profile = model.profile {
                StoredHotelStore.recordVisit(profile, in: modelContext)
            }
        }
    }

    /// Favourites are per site, because a booking is: the same inn on the other
    /// site is a different record.
    private func refreshFavorite(_ model: HotelDetailViewModel) {
        guard let id = model.hotelID else { return }
        isFavorite = StoredHotelStore.contains(
            kind: .favorite,
            provider: model.provider,
            hotelID: id,
            in: modelContext
        )
    }
}

// MARK: - Sections

private extension HotelDetailView {
    @ViewBuilder
    func providerPicker(_ model: HotelDetailViewModel) -> some View {
        let providers = model.availableProviders
        if providers.count > 1 {
            Picker("Booking site", selection: Binding(
                get: { model.provider },
                set: { provider in
                    model.provider = provider
                    refreshFavorite(model)
                }
            )) {
                ForEach(providers) { provider in
                    Text(provider.title)
                        .tag(provider)
                        .accessibilityIdentifier(YadoAccessibilityID.hotelProvider(provider.rawValue))
                }
            }
            .pickerStyle(.segmented)
        }
    }

    func header(_ model: HotelDetailViewModel) -> some View {
        let profile = model.profile
        return VStack(alignment: .leading, spacing: 10) {
            if let url = profile?.pictureURL ?? model.listing?.pictureURL {
                RemoteImage(url: url)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 14))
            }
            if let catchCopy = profile?.catchCopy ?? model.listing?.catchCopy {
                Text(catchCopy)
                    .font(.headline)
            }
            HStack(spacing: 10) {
                if let kind = profile?.kind ?? model.listing?.kind {
                    Text(kind)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: .capsule)
                }
                // Only Rakuten scores its inns, so this is empty on the Jalan
                // side of the control rather than zero.
                if let review = profile?.review {
                    Label(String(format: "%.1f", review.average), systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let count = review.count {
                        Text("(\(count) reviews)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    func mapSection(_ model: HotelDetailViewModel) -> (some View)? {
        guard let coordinate = model.profile?.coordinate ?? model.listing?.coordinate else {
            return Optional<AnyView>.none
        }
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
                    Marker(name, systemImage: "bed.double.fill", coordinate: point)
                }
                .frame(height: 180)
                .clipShape(.rect(cornerRadius: 14))
                .allowsHitTesting(false)

                if let url = mapsURL(name: name, coordinate: coordinate) {
                    Link("Open in Maps", destination: url)
                        .font(.footnote)
                }
            }
        )
    }

    @ViewBuilder
    func factsSection(_ model: HotelDetailViewModel) -> some View {
        let profile = model.profile
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Details")
            if let address = profile?.address ?? model.listing?.address {
                LabeledContent("Address") {
                    Text(profile?.postalCode.map { "〒\($0)\n\(address)" } ?? address)
                        .multilineTextAlignment(.trailing)
                }
            }
            if let checkIn = profile?.checkIn {
                LabeledContent("Check-in", value: checkIn)
            }
            if let checkOut = profile?.checkOut {
                LabeledContent("Check-out", value: checkOut)
            }
            if let area = (profile?.area ?? model.listing?.area)?.summary {
                LabeledContent("Region", value: area)
            }
            if let telephone = profile?.detail?.telephone {
                LabeledContent("Phone", value: telephone)
            }
        }
    }

    @ViewBuilder
    func accessSection(_ model: HotelDetailViewModel) -> some View {
        let access = model.profile?.access ?? model.listing?.access ?? []
        if !access.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Getting there")
                ForEach(access) { line in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(line.detail)
                            .font(.callout)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func captionSection(_ model: HotelDetailViewModel) -> some View {
        if let caption = model.profile?.caption {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("About this inn")
                Text(caption)
                    .font(.callout)
            }
        }
    }

    @ViewBuilder
    func plansSection(_ model: HotelDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Plans")
            StayConditionsEditor(stay: Binding(
                get: { model.stay },
                set: { conditions in
                    model.stay = conditions
                    // Remembered as they are set, so the next inn — and the
                    // next device — opens on the same stay.
                    stayConditions.update(conditions)
                }
            ))
            plans(model)
        }
        .accessibilityIdentifier(YadoAccessibilityID.hotelPlans)
    }

    @ViewBuilder
    func plans(_ model: HotelDetailViewModel) -> some View {
        switch model.plansPhase {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .needsCheckIn:
            // Rakuten has no undated mode at all, so there is nothing to show
            // until a date is picked. Jalan answers either way.
            Text("Choose a check-in date to see vacancy on Rakuten Travel.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case let .failed(message):
            // Rakuten's rate limit is the common one here, and it passes on its
            // own — so the line comes with a way to ask again rather than
            // leaving the screen stuck on it.
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Try again") {
                    Task { await model.loadPlans() }
                }
                .font(.footnote)
            }
        case .loaded where model.plans.isEmpty:
            Text("No bookable plans were found for these conditions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .loaded:
            ForEach(model.plans) { plan in
                if let url = plan.detailURL {
                    SafariLink(destination: url) {
                        PlanRow(plan: plan)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // Without this the row only responds where its text
                            // is; the gaps between the lines fall through.
                            .contentShape(Rectangle())
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
    func bookingButton(_ model: HotelDetailViewModel) -> some View {
        if let url = model.bookingURL {
            SafariLink(destination: url) {
                Text("Book on \(model.provider.title)")
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

    /// Opens the inn in Maps. Built from the coordinate rather than the address,
    /// which Maps often cannot resolve for a Japanese street address.
    func mapsURL(name: String, coordinate: GeoCoordinate) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "q", value: name)
        ]
        return components?.url
    }
}
