import Foundation

/// Where the app looks for the proxy.
///
/// Two sources, in this order:
///
/// 1. **A launch argument**, `-APIHost my-mac.local:8080`. Xcode puts `-key
///    value` pairs from a scheme's arguments into `UserDefaults`, so this needs
///    no parsing of its own. The `YadoSearch (Local)` scheme passes one, and it
///    is the knob to turn when running on a device — `localhost` means the phone
///    itself, so a device has to be pointed at the Mac by name or address.
/// 2. **`APIHost` in `Info.plist`**, written by Tuist from the `API_HOST` build
///    setting.
///
/// A host without a scheme is deliberate: `http` is chosen for a local address
/// and `https` for everything else, so a development build never has to declare
/// an App Transport Security exception for a real host.
enum APIHost {
    static func baseURL(bundle: Bundle, defaults: UserDefaults) -> URL? {
        let host = defaults.string(forKey: "APIHost")
            ?? bundle.object(forInfoDictionaryKey: "APIHost") as? String
        guard let host, !host.isEmpty else { return nil }
        return URL(string: "\(isLocal(host) ? "http" : "https")://\(host)")
    }

    /// Local addresses reached over plain HTTP. `NSAllowsLocalNetworking` in
    /// `Info.plist` is what permits it, and it covers exactly these.
    private static func isLocal(_ host: String) -> Bool {
        let name = host.split(separator: ":").first.map(String.init) ?? host
        return name == "localhost"
            || name == "127.0.0.1"
            || name == "[::1]"
            || name.hasSuffix(".local")
    }
}
