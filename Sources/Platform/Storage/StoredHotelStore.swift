import Foundation
import SwiftData
import YadoSearchCore

/// The private CloudKit database favourites, history and recent searches are
/// mirrored through.
public enum YadoSearchCloudKit {
    public static let containerIdentifier = "iCloud.org.ngsdev.iphone.Yado"

    /// Environment variable that turns mirroring off, for tests and for
    /// debugging against a purely local store.
    public static let disableEnvironmentKey = "YADOSEARCH_DISABLE_CLOUDKIT"

    /// Whether this process should even try to open a CloudKit-backed store.
    ///
    /// **This check is not an optimisation — it is what keeps the app from
    /// crashing.** `ModelContainer(for:configurations:)` accepts a CloudKit
    /// configuration without complaint even when the process has no iCloud
    /// entitlement; mirroring then fails *asynchronously*, on its own queue,
    /// with a trap inside CloudKit that no `try?` around the initialiser can
    /// catch. Simulator builds, CI builds and unsigned local builds are all in
    /// exactly that position.
    ///
    /// A signed-in iCloud account implies the entitlement is present and usable,
    /// which makes it the gate. Being wrong in the other direction is harmless:
    /// if the account disappears later, `YadoSearchModelContainer` falls back to
    /// the local store.
    public static var isAvailable: Bool {
        if ProcessInfo.processInfo.environment[disableEnvironmentKey] != nil {
            return false
        }
        if isRunningTests || isRunningPreviews {
            return false
        }
        return FileManager.default.ubiquityIdentityToken != nil
    }

    /// True inside a test process, whether hosted by XCTest or run as a bare
    /// swift-testing bundle by `swift test`.
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
            || Bundle.main.bundlePath.contains(".xctest")
            || ProcessInfo.processInfo.arguments.contains { $0.contains(".xctest") }
    }

    private static var isRunningPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

/// The SwiftData stack, with a fallback ladder.
///
/// CloudKit first, then a plain local store, then memory. Each rung covers a real
/// situation: a build without the iCloud entitlement or a device not signed in
/// cannot mirror; a store whose schema moved under an installed build cannot be
/// opened at all. Favourites and history are conveniences, not the point of the
/// app, so degrading beats refusing to launch.
public enum YadoSearchModelContainer {
    public static let schema = Schema([StoredHotel.self, StoredSearch.self])

    public static func make(inMemory: Bool = false) -> ModelContainer {
        if !inMemory {
            for configuration in syncedThenLocal() {
                if let container = try? ModelContainer(for: schema, configurations: configuration) {
                    return container
                }
            }
        }
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        } catch {
            // An in-memory container has nothing left to fail on.
            fatalError("Could not create an in-memory model container: \(error)")
        }
    }

    private static func syncedThenLocal() -> [ModelConfiguration] {
        var configurations: [ModelConfiguration] = []
        if YadoSearchCloudKit.isAvailable {
            configurations.append(
                ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private(YadoSearchCloudKit.containerIdentifier)
                )
            )
        }
        configurations.append(ModelConfiguration(schema: schema, isStoredInMemoryOnly: false))
        return configurations
    }
}

/// Reads and writes the two stored-inn lists through a `ModelContext`.
///
/// Free functions on the context rather than a stored service, so views can use
/// `@Query` for the lists and reach for this only when acting on them.
public enum StoredHotelStore {
    /// How many inns the history keeps. The 2010 release capped it too; without
    /// a cap the list grows forever and nobody ever scrolls to the bottom of it.
    public static let historyLimit = 100

    public static func contains(kind: StoredHotel.Kind, hotelID: String, in context: ModelContext) -> Bool {
        existing(kind: kind, hotelID: hotelID, in: context) != nil
    }

    /// Adds the inn, or does nothing if this list already has it.
    public static func add(_ hotel: Hotel, kind: StoredHotel.Kind, to context: ModelContext) {
        guard existing(kind: kind, hotelID: hotel.id, in: context) == nil else { return }
        context.insert(StoredHotel(kind: kind, hotel: hotel))
        try? context.save()
    }

    public static func remove(kind: StoredHotel.Kind, hotelID: String, from context: ModelContext) {
        guard let stored = existing(kind: kind, hotelID: hotelID, in: context) else { return }
        context.delete(stored)
        try? context.save()
    }

    /// Adds or removes, and reports what the inn's state became.
    @discardableResult
    public static func toggleFavorite(_ hotel: Hotel, in context: ModelContext) -> Bool {
        if existing(kind: .favorite, hotelID: hotel.id, in: context) == nil {
            add(hotel, kind: .favorite, to: context)
            return true
        }
        remove(kind: .favorite, hotelID: hotel.id, from: context)
        return false
    }

    /// Records a visit, moving the inn back to the top if it was already there,
    /// then drops whatever falls off the end.
    public static func recordVisit(_ hotel: Hotel, in context: ModelContext) {
        if let stored = existing(kind: .history, hotelID: hotel.id, in: context) {
            stored.savedAt = .now
            stored.name = hotel.name
            stored.catchCopy = hotel.catchCopy
            stored.pictureURLString = hotel.pictureURL?.absoluteString
        } else {
            context.insert(StoredHotel(kind: .history, hotel: hotel))
        }
        trimHistory(in: context)
        try? context.save()
    }

    public static func clear(kind: StoredHotel.Kind, in context: ModelContext) {
        for stored in fetch(kind: kind, in: context) {
            context.delete(stored)
        }
        try? context.save()
    }

    private static func trimHistory(in context: ModelContext) {
        let stored = fetch(kind: .history, in: context)
        guard stored.count > historyLimit else { return }
        for entry in stored[historyLimit...] {
            context.delete(entry)
        }
    }

    /// Newest first.
    private static func fetch(kind: StoredHotel.Kind, in context: ModelContext) -> [StoredHotel] {
        let raw = kind.rawValue
        let descriptor = FetchDescriptor<StoredHotel>(
            predicate: #Predicate { $0.kindRawValue == raw },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func existing(
        kind: StoredHotel.Kind,
        hotelID: String,
        in context: ModelContext
    ) -> StoredHotel? {
        let identifier = StoredHotel.identifier(kind: kind, hotelID: hotelID)
        var descriptor = FetchDescriptor<StoredHotel>(
            predicate: #Predicate { $0.id == identifier }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
