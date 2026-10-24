import Foundation

public struct UserSettings: Hashable, Codable, Sendable {
    public var favourites: [FavouriteTeam]
    public var useDeviceTimeZone: Bool

    public init(favourites: [FavouriteTeam], useDeviceTimeZone: Bool = true) {
        self.favourites = favourites
        self.useDeviceTimeZone = useDeviceTimeZone
    }

    public static let `default` = UserSettings(
        favourites: [
            FavouriteTeam(league: .nhl, code: "TOR"),
            FavouriteTeam(league: .nfl, code: "GB")
        ]
    )
}

public protocol KeyValueStore: Sendable {
    func data(forKey key: String) -> Data?
    func set(data: Data?, forKey key: String)
}

public final class MemoryKeyValueStore: KeyValueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data]

    public init(storage: [String: Data] = [:]) {
        self.storage = storage
    }

    public func data(forKey key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    public func set(data: Data?, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = data
    }
}

public struct UserDefaultsKeyValueStore: KeyValueStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let suiteName: String?

    public init(defaults: UserDefaults = .standard, suiteName: String? = nil) {
        self.defaults = defaults
        self.suiteName = suiteName
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func set(data: Data?, forKey key: String) {
        defaults.set(data, forKey: key)
    }
}

#if os(iOS) || os(tvOS) || os(macOS) || os(watchOS)
public struct UbiquitousKeyValueStore: KeyValueStore, Sendable {
    public init() {}

    public func data(forKey key: String) -> Data? {
        NSUbiquitousKeyValueStore.default.data(forKey: key)
    }

    public func set(data: Data?, forKey key: String) {
        if let data {
            NSUbiquitousKeyValueStore.default.set(data, forKey: key)
        } else {
            NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}
#endif

public final class SettingsStore: @unchecked Sendable {
    public static let storageKey = "sportsdesk.settings.v1"

    private let local: any KeyValueStore
    private let cloud: (any KeyValueStore)?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(local: any KeyValueStore, cloud: (any KeyValueStore)? = nil) {
        self.local = local
        self.cloud = cloud
    }

    public static func production() -> SettingsStore {
        #if os(iOS) || os(tvOS) || os(macOS) || os(watchOS)
        SettingsStore(local: UserDefaultsKeyValueStore(), cloud: UbiquitousKeyValueStore())
        #else
        SettingsStore(local: UserDefaultsKeyValueStore(), cloud: nil)
        #endif
    }

    public func load() -> UserSettings {
        if let cloudData = cloud?.data(forKey: Self.storageKey),
           let settings = try? decoder.decode(UserSettings.self, from: cloudData) {
            local.set(data: cloudData, forKey: Self.storageKey)
            return sanitized(settings)
        }
        if let localData = local.data(forKey: Self.storageKey),
           let settings = try? decoder.decode(UserSettings.self, from: localData) {
            return sanitized(settings)
        }
        return .default
    }

    public func save(_ settings: UserSettings) {
        let value = sanitized(settings)
        guard let data = try? encoder.encode(value) else { return }
        local.set(data: data, forKey: Self.storageKey)
        cloud?.set(data: data, forKey: Self.storageKey)
    }

    public func applyRemoteIfNewer() -> UserSettings {
        load()
    }

    private func sanitized(_ settings: UserSettings) -> UserSettings {
        var seen = Set<String>()
        let favourites = settings.favourites.filter { favourite in
            seen.insert(favourite.id).inserted
        }
        if favourites.isEmpty {
            return .default
        }
        return UserSettings(favourites: favourites, useDeviceTimeZone: settings.useDeviceTimeZone)
    }
}
