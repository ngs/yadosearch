import Foundation
import YadoSearchCore

/// Holds the area tree so the area picker opens instantly and keeps working
/// offline.
///
/// The tree is one ~56 KB response describing all 47 prefectures and everything
/// under them, and it changes about as often as Japan's administrative geography
/// does. So it is fetched once, cached in Application Support as the XML that
/// came back, and re-fetched only when there is no cache — a refresh is
/// available but never automatic.
public actor AreaCatalog {
    private let client: JalanAPIClient
    private let cacheURL: URL?
    private var tree: AreaTree?

    public init(client: JalanAPIClient, fileManager: FileManager = .default) {
        self.client = client
        cacheURL = try? fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "jalan-area-tree.xml")
    }

    /// The tree, from memory, then the disk cache, then the network.
    public func tree() async throws -> AreaTree {
        if let tree {
            return tree
        }
        if let cached = loadFromCache() {
            tree = cached
            return cached
        }
        return try await refresh()
    }

    /// Fetches a fresh copy and replaces the cache.
    @discardableResult
    public func refresh() async throws -> AreaTree {
        let fetched = try await client.areaTree()
        tree = fetched
        writeToCache(fetched)
        return fetched
    }

    private func loadFromCache() -> AreaTree? {
        guard
            let cacheURL,
            let data = try? Data(contentsOf: cacheURL),
            let root = try? XMLTree.parse(data)
        else {
            return nil
        }
        let cached = AreaTree(element: root)
        // A truncated or half-written file parses into an empty tree; treat that
        // as no cache at all rather than showing an empty picker forever.
        return cached.regions.isEmpty ? nil : cached
    }

    /// Caches the tree by re-encoding it, rather than by keeping the response
    /// body, so the file on disk always matches what the decoder produces.
    private func writeToCache(_ tree: AreaTree) {
        guard let cacheURL, let data = tree.xmlDocument.data(using: .utf8) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}

private extension AreaTree {
    /// Re-encodes the tree in the same shape `APICommon/AreaSearch` returns it,
    /// so `AreaTree(element:)` reads it straight back.
    var xmlDocument: String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Results><Area>"
        for region in regions {
            xml += "<Region cd=\"\(region.id.xmlEscaped)\" name=\"\(region.name.xmlEscaped)\">"
            for prefecture in region.prefectures {
                xml += "<Prefecture cd=\"\(prefecture.id.xmlEscaped)\" name=\"\(prefecture.name.xmlEscaped)\">"
                for largeArea in prefecture.largeAreas {
                    xml += "<LargeArea cd=\"\(largeArea.id.xmlEscaped)\" name=\"\(largeArea.name.xmlEscaped)\">"
                    for smallArea in largeArea.smallAreas {
                        xml += "<SmallArea cd=\"\(smallArea.id.xmlEscaped)\" name=\"\(smallArea.name.xmlEscaped)\"/>"
                    }
                    xml += "</LargeArea>"
                }
                xml += "</Prefecture>"
            }
            xml += "</Region>"
        }
        return xml + "</Area></Results>"
    }
}

private extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
