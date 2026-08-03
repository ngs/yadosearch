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

public extension AreaTree {
    /// Decodes the `APICommon/AreaSearch` document.
    ///
    /// Public because the tree is cached on disk as the XML it arrived as, and
    /// the layer that owns that cache has to be able to read it back.
    init(element: XMLTreeNode) {
        let area = element.child(named: "Area") ?? element
        regions = area.children(named: "Region").compactMap { regionElement in
            guard
                let id = regionElement.attribute("cd"),
                let name = regionElement.attribute("name")
            else {
                return nil
            }
            let prefectures = regionElement.children(named: "Prefecture").compactMap { prefectureElement -> Prefecture? in
                guard
                    let id = prefectureElement.attribute("cd"),
                    let name = prefectureElement.attribute("name")
                else {
                    return nil
                }
                let largeAreas = prefectureElement.children(named: "LargeArea").compactMap { largeElement -> LargeArea? in
                    guard
                        let id = largeElement.attribute("cd"),
                        let name = largeElement.attribute("name")
                    else {
                        return nil
                    }
                    let smallAreas = largeElement.children(named: "SmallArea").compactMap { smallElement -> SmallArea? in
                        guard
                            let id = smallElement.attribute("cd"),
                            let name = smallElement.attribute("name")
                        else {
                            return nil
                        }
                        return SmallArea(id: id, name: name)
                    }
                    return LargeArea(id: id, name: name, smallAreas: smallAreas)
                }
                return Prefecture(id: id, name: name, largeAreas: largeAreas)
            }
            return Region(id: id, name: name, prefectures: prefectures)
        }
    }
}
