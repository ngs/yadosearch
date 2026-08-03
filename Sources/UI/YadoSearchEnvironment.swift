import Foundation
import SwiftUI
import YadoSearchCore
import YadoSearchPlatform

/// The services the screens share, resolved once at launch.
///
/// `client` is optional on purpose. The Jalan application key is injected at
/// project-generation time and a build can legitimately be made without one —
/// every CI build is — so "not configured" is a state the UI renders rather than
/// a precondition it assumes.
///
/// Deliberately free of anything main-actor bound, so it can be an environment
/// value with a default. The location provider is main-actor state owned by the
/// one screen that asks for a fix, not a shared service.
public struct YadoSearchEnvironment: Sendable {
    public let client: JalanAPIClient?
    public let areaCatalog: AreaCatalog?
    public let stationSearch = StationSearchService()
    /// Every outbound jalan.net link goes through this, so a booking made from
    /// the app is credited. It needs no key of its own — the IDs are public.
    public let affiliate = JalanAffiliate.littleApps

    public var isConfigured: Bool { client != nil }

    public init(configuration: JalanAPIClient.Configuration?) {
        guard let configuration else {
            client = nil
            areaCatalog = nil
            return
        }
        let client = JalanAPIClient(configuration: configuration)
        self.client = client
        areaCatalog = AreaCatalog(client: client)
    }

    public init(bundle: Bundle) {
        self.init(configuration: JalanAPIClient.Configuration.fromBundle(bundle))
    }
}

public extension EnvironmentValues {
    /// Defaults to an unconfigured environment, so previews and tests need no setup.
    @Entry var yadoSearch = YadoSearchEnvironment(configuration: nil)
}
