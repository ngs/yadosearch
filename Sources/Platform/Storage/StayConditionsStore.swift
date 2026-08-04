import Foundation
import Observation
import YadoSearchCore

/// Where the stay conditions live between launches, and between devices.
///
/// The date, the nights, the rooms and the party are what the vacancy search
/// asks with, and they are the same on every screen — so they are remembered
/// rather than re-entered. Two stores hold them: `UserDefaults` locally, so a
/// launch with no network still opens on what was last used, and iCloud's
/// key-value store, so a phone and a Mac agree.
///
/// **A check-in date in the past clears the lot.** Yesterday's conditions
/// describe a stay that cannot be booked, and quietly searching them is worse
/// than starting again: the app would report no vacancy for a night that has
/// already gone.
@MainActor
@Observable
public final class StayConditionsStore {
    public static let key = "stayConditions"

    /// The one the app uses. Tests build their own over in-memory stores.
    public static let shared = StayConditionsStore(
        local: UserDefaults.standard,
        cloud: NSUbiquitousKeyValueStore.default
    )

    public private(set) var conditions: StayConditions

    private let local: KeyValueStoring
    private let cloud: KeyValueStoring?
    private let now: @Sendable () -> Date
    /// Held so the notification is only ever registered once; `deinit` cannot
    /// touch main-actor state, so removal is left to the observer's own
    /// lifetime — the store lives as long as the app does.
    private var observer: NSObjectProtocol?

    public init(
        local: KeyValueStoring,
        cloud: KeyValueStoring? = nil,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.local = local
        self.cloud = cloud
        self.now = now
        conditions = StayConditions()
        conditions = loadStored() ?? StayConditions()

        if let cloud = cloud as? NSUbiquitousKeyValueStore {
            // Another device wrote; take what it wrote, subject to the same
            // staleness rule.
            observer = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: cloud,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.reloadFromCloud() }
            }
            cloud.synchronize()
        }
    }

    /// Records what the user chose, everywhere at once.
    public func update(_ newConditions: StayConditions) {
        guard newConditions != conditions else { return }
        conditions = newConditions
        guard let data = try? JSONEncoder().encode(newConditions) else { return }
        local.setData(data, forKey: Self.key)
        cloud?.setData(data, forKey: Self.key)
    }

    /// Drops what is stored, on both sides, and goes back to the defaults.
    public func clear() {
        conditions = StayConditions()
        local.setData(nil, forKey: Self.key)
        cloud?.setData(nil, forKey: Self.key)
    }

    /// Re-reads the stores, discarding a stay whose date has passed. Called at
    /// launch and whenever the app comes back to the foreground: a phone left
    /// open overnight would otherwise keep yesterday.
    public func refresh() {
        conditions = loadStored() ?? StayConditions()
    }

    private func reloadFromCloud() {
        guard let data = cloud?.data(forKey: Self.key),
              let stored = try? JSONDecoder().decode(StayConditions.self, from: data)
        else { return }
        conditions = isStale(stored) ? StayConditions() : stored
    }

    /// iCloud first, because it is the one that can have changed elsewhere;
    /// `UserDefaults` is what answers when iCloud is off or empty.
    private func loadStored() -> StayConditions? {
        let data = cloud?.data(forKey: Self.key) ?? local.data(forKey: Self.key)
        guard let data,
              let stored = try? JSONDecoder().decode(StayConditions.self, from: data)
        else { return nil }
        guard !isStale(stored) else {
            clear()
            return nil
        }
        return stored
    }

    /// A date before today. The night is measured in days, so a check-in
    /// earlier today still counts as today.
    private func isStale(_ stored: StayConditions) -> Bool {
        guard let checkIn = stored.checkIn else { return false }
        return checkIn < Calendar.current.startOfDay(for: now())
    }
}

/// The part of a key-value store this needs, so the tests can hold one in
/// memory and the app can hand over `UserDefaults` and iCloud's.
public protocol KeyValueStoring: AnyObject {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data?, forKey key: String)
}

extension UserDefaults: KeyValueStoring {
    public func setData(_ data: Data?, forKey key: String) {
        set(data, forKey: key)
    }
}

extension NSUbiquitousKeyValueStore: KeyValueStoring {
    public func setData(_ data: Data?, forKey key: String) {
        if let data {
            set(data, forKey: key)
        } else {
            removeObject(forKey: key)
        }
        synchronize()
    }
}
