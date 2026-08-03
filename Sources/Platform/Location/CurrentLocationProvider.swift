import CoreLocation
import Foundation
import Observation
import YadoSearchCore

/// Gets one fix of the device's position, for the "inns near me" search.
///
/// Built on `CLLocationUpdate.liveUpdates()` rather than the delegate API: it
/// prompts for authorization on its own, reports refusal as a value instead of a
/// callback, and is cancelled by simply leaving the loop — which is exactly the
/// shape a one-shot request wants.
@MainActor
@Observable
public final class CurrentLocationProvider {
    public enum State: Sendable, Equatable {
        case idle
        case locating
        case located(GeoCoordinate)
        /// The user said no. Recoverable only in Settings, so the UI has to say so.
        case denied
        /// Location services are off device-wide, or the fix never arrived.
        case unavailable
    }

    public private(set) var state: State = .idle
    /// A human-readable name for the fix, once the reverse geocoder answers.
    /// Nil while it is still resolving, and if it never does.
    public private(set) var placeName: String?

    private let geocoder = ReverseGeocoder()
    private var task: Task<Void, Never>?

    public init() {}

    public var coordinate: GeoCoordinate? {
        guard case let .located(coordinate) = state else { return nil }
        return coordinate
    }

    /// Requests a single fix. Calling again while one is in flight replaces it.
    public func requestLocation() {
        task?.cancel()
        state = .locating
        placeName = nil
        task = Task { [weak self] in
            await self?.updateFromLiveUpdates()
            await self?.resolvePlaceName()
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
        if state == .locating {
            state = .idle
        }
    }

    /// Runs after the fix, never instead of it: the coordinate is what the
    /// search needs, and the name is only there to be read.
    private func resolvePlaceName() async {
        guard let coordinate, !Task.isCancelled else { return }
        let name = await geocoder.placeName(for: coordinate)
        guard !Task.isCancelled, self.coordinate == coordinate else { return }
        placeName = name
    }

    private func updateFromLiveUpdates() async {
        do {
            for try await update in CLLocationUpdate.liveUpdates(.default) {
                if Task.isCancelled { return }
                if update.authorizationDenied || update.authorizationDeniedGlobally {
                    state = .denied
                    return
                }
                if let location = update.location {
                    state = .located(
                        GeoCoordinate(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude
                        )
                    )
                    return
                }
            }
            // The sequence finished without ever producing a fix.
            if state == .locating {
                state = .unavailable
            }
        } catch {
            if !Task.isCancelled {
                state = .unavailable
            }
        }
    }
}
