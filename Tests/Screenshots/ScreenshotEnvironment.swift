import Foundation

/// How `Scripts/screenshots.sh` talks to the capture run.
///
/// The script owns everything that varies — which language, which proxy port,
/// where the files land — and hands it over in a `config.json` it drops in the
/// *work directory* before starting the run. The test reads it there and writes
/// the PNGs back beside it.
///
/// A file rather than environment variables, because there is no dependable way
/// to get a variable from `xcodebuild` into a UI test *runner*: `TEST_RUNNER_…`
/// reaches the build, not the runner process. A directory both sides can see is
/// the one channel that behaves the same on a simulator and on the Mac.
enum ScreenshotEnvironment {
    /// What the script asks for. Mirrored by the `config.json` it writes.
    struct Configuration: Decodable {
        /// Language to render the app in: `ja` or `en`.
        var language: String
        /// Region for the formatters, e.g. `JP`. Without it a Japanese UI would
        /// draw US date formats.
        var region: String
        /// `host:port` of the stub proxy the script is running, which is what
        /// makes every run photograph the same inns at the same prices.
        var apiHost: String
        /// `landscape` for the iPad, whose App Store shots are wide — the
        /// sidebar and the list are both in frame that way, which is the whole
        /// argument for the iPad build. Absent means portrait.
        var orientation: String?
        /// Whether the host takes the picture instead of the test. macOS only:
        /// a UI test can photograph the window there, but it flattens it — the
        /// rounded corners come back filled with black.
        var externalCapture: Bool?
    }

    /// The directory shared with the script: `config.json` in, PNGs out.
    ///
    /// On a simulator the test cannot reach the host's filesystem, but the
    /// device's own data container is a plain directory on the host — which is
    /// how the script both delivers the config and collects the results. On
    /// macOS the runner is sandboxed, so its own container serves the same
    /// purpose.
    static let workDirectory: URL = {
        let name = "org.ngsdev.iphone.Yado.screenshots"
        if let shared = ProcessInfo.processInfo.environment["SIMULATOR_SHARED_RESOURCES_DIRECTORY"] {
            return URL(fileURLWithPath: shared)
                .appendingPathComponent("Library/Caches")
                .appendingPathComponent(name)
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Caches")
            .appendingPathComponent(name)
    }()

    /// The run's configuration, or a failure loud enough to stop the run: a
    /// screenshot session that quietly fell back to defaults would photograph
    /// the wrong language in silence.
    static let configuration: Configuration = {
        let url = workDirectory.appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: url) else {
            fatalError("No screenshot config at \(url.path). Run Scripts/screenshots.sh, not the scheme.")
        }
        do {
            return try JSONDecoder().decode(Configuration.self, from: data)
        } catch {
            fatalError("Malformed screenshot config at \(url.path): \(error)")
        }
    }()

    /// Launch arguments for the app: the language to render in, and the proxy
    /// to talk to.
    ///
    /// `-AppleLanguages` / `-AppleLocale` are read by Foundation at startup and
    /// are the supported way to run a build in another language. `-APIHost` is
    /// the app's own knob — the same one the `YadoSearch (Local)` scheme uses —
    /// so nothing in the app knows it is being photographed.
    static var appArguments: [String] {
        let configuration = configuration
        let locale = configuration.language.replacingOccurrences(of: "-", with: "_")
        var arguments = [
            "-AppleLanguages", "(\(configuration.language))",
            "-AppleLocale", "\(locale)_\(configuration.region)",
            "-APIHost", configuration.apiHost
        ]
        #if os(macOS)
        // Otherwise AppKit restores whatever window frame this Mac last used,
        // and the shot comes out at some arbitrary size instead of the app's
        // 1000x720 default.
        arguments += ["-ApplePersistenceIgnoreState", "YES"]
        #endif
        return arguments
    }
}
