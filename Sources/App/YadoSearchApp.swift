import SwiftData
import SwiftUI
import YadoSearchPlatform
import YadoSearchUI

@main
struct YadoSearchApp: App {
    /// Resolved once from the bundle, so the whole app agrees on whether there
    /// is an API key — including the screens that render its absence.
    private let searchEnvironment = YadoSearchEnvironment(bundle: .main)
    private let modelContainer = YadoSearchModelContainer.make()

    var body: some Scene {
        WindowGroup {
            YadoSearchRootView()
                .environment(\.yadoSearch, searchEnvironment)
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .defaultSize(width: 1_000, height: 720)
        #endif
    }
}
