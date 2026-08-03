import Foundation
import SwiftUI
import YadoSearchCore
import YadoSearchPlatform

/// The services the screens share, resolved once at launch.
///
/// Deliberately free of anything main-actor bound, so it can be an environment
/// value with a default. The location provider is main-actor state owned by the
/// one screen that asks for a fix, not a shared service.
public struct YadoSearchEnvironment: Sendable {
    public let client: JalanAPIClient
    public let areaCatalog: AreaCatalog
    public let stationSearch = StationSearchService()
    /// Every outbound jalan.net link goes through this, so a booking made from
    /// the app is credited. It needs no key of its own — the IDs are public.
    public let affiliate = JalanAffiliate.littleApps

    public init(configuration: JalanAPIClient.Configuration) {
        let client = JalanAPIClient(configuration: configuration)
        self.client = client
        areaCatalog = AreaCatalog(client: client)
    }

    /// Reads the key baked into the bundle at project-generation time.
    ///
    /// Traps when there is none. Every screen in the app needs the API, so a
    /// build without a key is a broken build, not a state worth rendering — and
    /// a crash on the first launch is how it gets noticed before it ships.
    public init(bundle: Bundle) {
        guard let configuration = JalanAPIClient.Configuration.fromBundle(bundle) else {
            fatalError(
                """
                JalanAPIKey is missing from Info.plist. Export TUIST_JALAN_API_KEY \
                (see .envrc) and run `tuist generate` again.
                """
            )
        }
        self.init(configuration: configuration)
    }
}

public extension EnvironmentValues {
    /// Previews and tests get a client with no key: it reaches the network and
    /// is turned away, which is a far better failure for them than a trap.
    @Entry var yadoSearch = YadoSearchEnvironment(
        configuration: JalanAPIClient.Configuration(applicationKey: "")
    )
}
