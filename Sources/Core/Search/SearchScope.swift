import Foundation

/// Which sites a search asks.
///
/// Three of the four ways of searching reach both providers, and until now they
/// always did. This is what makes "by name, but only on 楽天" expressible; the
/// proxy takes it as `providers`.
///
/// **It narrows and never widens.** An area search reaches whichever provider's
/// codes it carries, so `.both` there would be a promise nothing can keep —
/// `SearchTarget.requiredScope` is what says so, and the search screen offers
/// only the two real choices when an area is being picked.
public enum SearchScope: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case jalan
    case rakuten
    case both

    public var id: String { rawValue }

    /// What is sent as `providers`. Empty for `.both`, which is the proxy's own
    /// default and needs no parameter.
    public var providers: [Provider] {
        switch self {
        case .jalan: [.jalan]
        case .rakuten: [.rakuten]
        case .both: []
        }
    }

    public init(_ provider: Provider) {
        switch provider {
        case .jalan: self = .jalan
        case .rakuten: self = .rakuten
        }
    }

    /// The single provider this names, or `nil` for `.both`.
    public var provider: Provider? {
        switch self {
        case .jalan: .jalan
        case .rakuten: .rakuten
        case .both: nil
        }
    }

    public var title: String {
        switch self {
        case .jalan: String(localized: "Jalan")
        case .rakuten: String(localized: "Rakuten Travel")
        case .both: String(localized: "Both")
        }
    }
}
