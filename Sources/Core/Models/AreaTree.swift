import Foundation

/// Jalan's four-level area hierarchy: 広域 → 都道府県 → 大エリア → 小エリア.
///
/// The whole tree arrives in one ~56 KB response from `APICommon/AreaSearch`,
/// which is the only place the area *codes* exist — a hotel search response
/// names an inn's areas but never codes them, so drilling down needs this.
public struct AreaTree: Sendable, Hashable, Codable {
    public struct SmallArea: Sendable, Hashable, Identifiable, Codable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public struct LargeArea: Sendable, Hashable, Identifiable, Codable {
        public let id: String
        public let name: String
        public let smallAreas: [SmallArea]

        public init(id: String, name: String, smallAreas: [SmallArea]) {
            self.id = id
            self.name = name
            self.smallAreas = smallAreas
        }
    }

    public struct Prefecture: Sendable, Hashable, Identifiable, Codable {
        public let id: String
        public let name: String
        public let largeAreas: [LargeArea]

        public init(id: String, name: String, largeAreas: [LargeArea]) {
            self.id = id
            self.name = name
            self.largeAreas = largeAreas
        }
    }

    public struct Region: Sendable, Hashable, Identifiable, Codable {
        public let id: String
        public let name: String
        public let prefectures: [Prefecture]

        public init(id: String, name: String, prefectures: [Prefecture]) {
            self.id = id
            self.name = name
            self.prefectures = prefectures
        }
    }

    public let regions: [Region]

    public init(regions: [Region]) {
        self.regions = regions
    }
}
