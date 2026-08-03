import Foundation
import Observation
import YadoSearchPlatform

/// Looks stations up by name so a proximity search can be centred on one.
@MainActor
@Observable
public final class StationSearchViewModel {
    public private(set) var stations: [Station] = []
    public private(set) var isSearching = false
    public private(set) var errorMessage: String?
    /// True once a search has run and come back with nothing, which is what
    /// separates "no matches" from "nothing typed yet".
    public private(set) var hasSearched = false

    private let service: StationSearchService
    private var searchTask: Task<Void, Never>?

    public init(service: StationSearchService) {
        self.service = service
    }

    /// Debounced: the field searches as it is typed, and MapKit is rate-limited,
    /// so each keystroke cancels the request the one before it started.
    public func search(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            stations = []
            errorMessage = nil
            hasSearched = false
            isSearching = false
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.performSearch(trimmed)
        }
    }

    private func performSearch(_ text: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let found = try await service.search(text)
            guard !Task.isCancelled else { return }
            stations = found
            errorMessage = nil
            hasSearched = true
        } catch {
            guard !Task.isCancelled else { return }
            stations = []
            errorMessage = error.localizedDescription
            hasSearched = true
        }
    }
}
