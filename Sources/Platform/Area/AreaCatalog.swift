import Foundation
import YadoSearchCore

/// Holds the area tree so the area picker opens instantly and keeps working
/// offline.
///
/// The tree describes all 47 prefectures and everything under them, and it
/// changes about as often as Japan's administrative geography does. So it is
/// fetched once, cached in Application Support, and re-fetched only when there
/// is no cache — a refresh is available but never automatic.
public actor AreaCatalog {
    private let client: YadoSearchAPIClient
    private let cacheURL: URL?
    private var tree: AreaTree?

    public init(client: YadoSearchAPIClient, fileManager: FileManager = .default) {
        self.client = client
        cacheURL = try? fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "jalan-area-tree.json")
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
        let fetched = try await client.jalanAreaTree()
        tree = fetched
        writeToCache(fetched)
        return fetched
    }

    private func loadFromCache() -> AreaTree? {
        guard
            let cacheURL,
            let data = try? Data(contentsOf: cacheURL),
            let cached = try? JSONDecoder().decode(AreaTree.self, from: data)
        else {
            return nil
        }
        // A truncated or half-written file decodes into an empty tree; treat
        // that as no cache at all rather than showing an empty picker forever.
        return cached.regions.isEmpty ? nil : cached
    }

    private func writeToCache(_ tree: AreaTree) {
        guard let cacheURL, let data = try? JSONEncoder().encode(tree) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
