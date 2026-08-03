import Foundation

/// Rakuten's four-level classification: 大区分 → 中区分 → 小区分 → 細区分.
///
/// A separate type from `AreaTree` rather than a reuse of it, because the two
/// are different schemes and not two spellings of one. The codes are strings
/// (`japan`, `hokkaido`, `sapporo`, `A`), the whole country hangs off a single
/// large class, and — the part that shapes the picker — **only the bottom is
/// searchable**: a small class with detail classes must be narrowed to one of
/// them, and nothing above the small class can be searched at all.
public struct RakutenAreaTree: Sendable, Hashable, Codable {
    public struct DetailClass: Sendable, Hashable, Identifiable, Codable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public struct SmallClass: Sendable, Hashable, Identifiable, Codable {
        public let id: String
        public let name: String
        public let detailClasses: [DetailClass]

        public init(id: String, name: String, detailClasses: [DetailClass]) {
            self.id = id
            self.name = name
            self.detailClasses = detailClasses
        }

        /// Whether this small class can be searched as it is. When it cannot,
        /// one of its detail classes has to be picked instead — Rakuten answers
        /// `specify valid detailClassCode` otherwise.
        public var isSearchable: Bool { detailClasses.isEmpty }
    }

    public struct MiddleClass: Sendable, Hashable, Identifiable, Codable {
        public let id: String
        public let name: String
        public let smallClasses: [SmallClass]

        public init(id: String, name: String, smallClasses: [SmallClass]) {
            self.id = id
            self.name = name
            self.smallClasses = smallClasses
        }
    }

    public struct LargeClass: Sendable, Hashable, Identifiable, Codable {
        public let id: String
        public let name: String
        public let middleClasses: [MiddleClass]

        public init(id: String, name: String, middleClasses: [MiddleClass]) {
            self.id = id
            self.name = name
            self.middleClasses = middleClasses
        }
    }

    public let largeClasses: [LargeClass]

    public init(largeClasses: [LargeClass]) {
        self.largeClasses = largeClasses
    }
}
