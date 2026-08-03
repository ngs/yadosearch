import Foundation

/// Real responses captured from `jws.jalan.net`, with the application key
/// replaced by `TEST_KEY` — it appears inside every `HotelDetailURL` the service
/// hands back, and these files are committed.
enum Fixture {
    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "xml", subdirectory: "Fixtures") else {
            throw FixtureError.missing(name)
        }
        return try Data(contentsOf: url)
    }

    enum FixtureError: Error {
        case missing(String)
    }
}
