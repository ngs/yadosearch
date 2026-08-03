import Foundation

/// Which booking site an inn, an offer or a plan came from.
///
/// The proxy merges the two into one search result, so a single inn commonly
/// carries an offer from each. Everything that identifies an inn — the ID, the
/// booking link, the plans — is per provider, because **the IDs collide between
/// them**: `137869` is a different inn on each site.
public enum Provider: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case jalan
    case rakuten

    public var id: String { rawValue }
}

// Without this, a `[Provider: …]` decodes from a JSON *array* of alternating
// keys and values rather than from an object — that is what `Dictionary` falls
// back to when its key is neither `String`, `Int`, nor a coding key. The proxy
// sends `{"jalan": 51, "rakuten": 7}`, so the keys have to be spellable.
extension Provider: CodingKeyRepresentable {}
