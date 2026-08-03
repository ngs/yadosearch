import Foundation
import Observation
import YadoSearchCore
import YadoSearchPlatform

/// Loads Jalan's area tree for the drill-down picker.
@MainActor
@Observable
public final class AreaPickerViewModel {
    public enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    public private(set) var tree = AreaTree(regions: [])
    public private(set) var phase: Phase = .loading

    private let catalog: AreaCatalog

    public init(catalog: AreaCatalog) {
        self.catalog = catalog
    }

    public func load() async {
        phase = .loading
        do {
            tree = try await catalog.tree()
            phase = .loaded
        } catch {
            phase = .failed(searchErrorMessage(for: error))
        }
    }

    /// Discards the cache and fetches the tree again.
    public func refresh() async {
        do {
            tree = try await catalog.refresh()
            phase = .loaded
        } catch {
            phase = .failed(searchErrorMessage(for: error))
        }
    }
}

/// The same, for Rakuten's classification.
///
/// A second type rather than a generic one: the trees are different shapes, and
/// the little this shares with `AreaPickerViewModel` is not worth a type
/// parameter running through both pickers.
@MainActor
@Observable
public final class RakutenAreaPickerViewModel {
    public private(set) var tree = RakutenAreaTree(largeClasses: [])
    public private(set) var phase: AreaPickerViewModel.Phase = .loading

    private let catalog: AreaCatalog

    public init(catalog: AreaCatalog) {
        self.catalog = catalog
    }

    public func load() async {
        phase = .loading
        do {
            tree = try await catalog.rakutenTree()
            phase = .loaded
        } catch {
            phase = .failed(searchErrorMessage(for: error))
        }
    }
}
