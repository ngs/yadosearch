import Foundation
import YadoSearchCore

/// Holds the area trees so an area picker opens instantly and keeps working
/// offline.
///
/// There are two of them, one per provider, because the two schemes have no
/// codes in common — picking a place on one says nothing about the other. Each
/// describes the whole country and changes about as often as Japan's
/// administrative geography does, so each is fetched once, cached in
/// Application Support, and re-fetched only when there is no cache. A refresh
/// is available but never automatic.
public actor AreaCatalog {
    private let client: YadoSearchAPIClient
    private let jalanCacheURL: URL?
    private let rakutenCacheURL: URL?
    private var jalanTree: AreaTree?
    private var rakutenAreaTree: RakutenAreaTree?

    public init(client: YadoSearchAPIClient, fileManager: FileManager = .default) {
        self.client = client
        let directory = try? fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        jalanCacheURL = directory?.appending(path: "jalan-area-tree.json")
        rakutenCacheURL = directory?.appending(path: "rakuten-area-tree.json")
    }

    /// Jalan's tree, from memory, then the disk cache, then the network.
    public func tree() async throws -> AreaTree {
        if let jalanTree {
            return jalanTree
        }
        if let cached: AreaTree = load(from: jalanCacheURL, keeping: { !$0.regions.isEmpty }) {
            jalanTree = cached
            return cached
        }
        return try await refresh()
    }

    /// Fetches a fresh copy of Jalan's tree and replaces the cache.
    @discardableResult
    public func refresh() async throws -> AreaTree {
        let fetched = try await client.jalanAreaTree()
        jalanTree = fetched
        write(fetched, to: jalanCacheURL)
        return fetched
    }

    /// Rakuten's classification, cached the same way.
    public func rakutenTree() async throws -> RakutenAreaTree {
        if let rakutenAreaTree {
            return rakutenAreaTree
        }
        if let cached: RakutenAreaTree = load(from: rakutenCacheURL, keeping: { !$0.largeClasses.isEmpty }) {
            rakutenAreaTree = cached
            return cached
        }
        return try await refreshRakuten()
    }

    @discardableResult
    public func refreshRakuten() async throws -> RakutenAreaTree {
        let fetched = try await client.rakutenAreaTree()
        rakutenAreaTree = fetched
        write(fetched, to: rakutenCacheURL)
        return fetched
    }

    /// `keeping` is what rejects a truncated or half-written file: it decodes
    /// into an empty tree, and an empty tree cached forever is a picker that
    /// never fills in. Treat it as no cache at all.
    private func load<Tree: Decodable>(from url: URL?, keeping isUsable: (Tree) -> Bool) -> Tree? {
        guard
            let url,
            let data = try? Data(contentsOf: url),
            let cached = try? JSONDecoder().decode(Tree.self, from: data),
            isUsable(cached)
        else {
            return nil
        }
        return cached
    }

    private func write(_ tree: some Encodable, to url: URL?) {
        guard let url, let data = try? JSONEncoder().encode(tree) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
