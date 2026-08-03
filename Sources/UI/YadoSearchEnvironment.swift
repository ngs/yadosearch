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
    public let client: YadoSearchAPIClient
    public let areaCatalog: AreaCatalog
    public let stationSearch = StationSearchService()
    /// Every outbound jalan.net link goes through this, so a booking made from
    /// the app is credited. It needs no key of its own — the IDs are public.
    public let affiliate = JalanAffiliate.littleApps

    public init(configuration: YadoSearchAPIClient.Configuration) {
        let client = YadoSearchAPIClient(configuration: configuration)
        self.client = client
        areaCatalog = AreaCatalog(client: client)
    }

    /// Resolves the proxy's address from the launch arguments and the bundle.
    ///
    /// Traps when there is none. Every screen in the app needs the API, so a
    /// build that does not know where to find it is a broken build rather than
    /// a state worth rendering — and a crash on the first launch is how that
    /// gets noticed before it ships.
    public init(bundle: Bundle, defaults: UserDefaults = .standard) {
        guard let baseURL = APIHost.baseURL(bundle: bundle, defaults: defaults) else {
            fatalError(
                """
                No API host. Run the `YadoSearch (Local)` scheme, pass \
                `-APIHost host:port` as a launch argument, or set API_HOST in \
                Project.swift and run `tuist generate` again.
                """
            )
        }
        self.init(configuration: YadoSearchAPIClient.Configuration(baseURL: baseURL))
    }
}

public extension EnvironmentValues {
    /// Previews and tests get a client pointed at a proxy running locally: it
    /// either answers or the request fails, which is a far better failure for
    /// them than a trap.
    @Entry var yadoSearch = YadoSearchEnvironment(
        configuration: YadoSearchAPIClient.Configuration(
            baseURL: URL(string: "http://localhost:8080") ?? URL(filePath: "/")
        )
    )
}
