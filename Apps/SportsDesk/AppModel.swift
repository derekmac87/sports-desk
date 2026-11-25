import Combine
import Foundation
import SportsDeskCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var settings: UserSettings
    @Published private(set) var dashboards: [TeamDashboard] = []
    @Published private(set) var failures: [DashboardFailure] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var lastUpdated: Date?

    let catalog = TeamCatalog.shared
    let settingsStore: SettingsStore
    let service: DashboardService

    private var refreshTask: Task<DashboardLoadResult, Never>?
    private var autoRefreshTask: Task<Void, Never>?
    private var cloudObserver: (any NSObjectProtocol)?

    init(
        settingsStore: SettingsStore = .production(),
        service: DashboardService = .live()
    ) {
        self.settingsStore = settingsStore
        self.service = service
        self.settings = settingsStore.load()
        observeCloud()
    }

    var isICloudAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }

    func board(id: String) -> TeamDashboard? {
        dashboards.first { $0.id == id }
    }

    func isFavourite(_ team: TeamSummary) -> Bool {
        settings.favourites.contains { $0.id == team.id.description }
    }

    // MARK: Loading

    func bootstrap() async {
        startAutoRefresh()
        await refresh()
    }

    /// A newer refresh supersedes an in-flight one so stale results never overwrite fresh ones.
    func refresh() async {
        refreshTask?.cancel()
        let favourites = settings.favourites
        let service = service
        let task = Task { await service.dashboards(for: favourites) }
        refreshTask = task
        isLoading = true
        let result = await task.value
        guard !task.isCancelled else { return }
        withAnimation(.smooth) {
            dashboards = result.boards
            failures = result.failures
            hasLoaded = true
        }
        lastUpdated = Date()
        isLoading = false
    }

    func sceneBecameActive() {
        startAutoRefresh()
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < 60 { return }
        Task { await refresh() }
    }

    func sceneWentToBackground() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.nextRefreshInterval ?? 600
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, let self else { return }
                await self.refresh()
            }
        }
    }

    /// 30 s during live games, 60 s around start time, 10 min otherwise.
    var nextRefreshInterval: TimeInterval {
        let games = dashboards.compactMap(\.game)
        if games.contains(where: { $0.phase == .live }) { return 30 }
        let now = Date()
        let startingSoon = games.contains { game in
            guard game.phase == .upcoming, let start = game.start else { return false }
            return start.timeIntervalSince(now) < 15 * 60
        }
        return startingSoon ? 60 : 600
    }

    // MARK: Favourites

    func addFavourite(_ team: TeamSummary) {
        guard !isFavourite(team) else { return }
        var next = settings
        next.favourites.append(FavouriteTeam(league: team.league, code: team.abbreviation))
        save(next)
        Task { await refresh() }
    }

    func removeFavourite(_ favourite: FavouriteTeam) {
        var next = settings
        next.favourites.removeAll { $0.id == favourite.id }
        save(next)
    }

    func removeFavourites(at offsets: IndexSet) {
        var next = settings
        next.favourites.remove(atOffsets: offsets)
        save(next)
    }

    func moveFavourite(from source: IndexSet, to destination: Int) {
        var next = settings
        next.favourites.move(fromOffsets: source, toOffset: destination)
        save(next)
    }

    func moveFavourite(_ favourite: FavouriteTeam, by delta: Int) {
        guard let index = settings.favourites.firstIndex(of: favourite) else { return }
        let target = index + delta
        guard settings.favourites.indices.contains(target) else { return }
        var next = settings
        next.favourites.swapAt(index, target)
        save(next)
    }

    func restoreDefaults() {
        save(.default)
        Task { await refresh() }
    }

    func reloadFromICloud() {
        let latest = settingsStore.load()
        guard latest != settings else { return }
        let needsFetch = Set(latest.favourites.map(\.id)) != Set(settings.favourites.map(\.id))
        settings = latest
        syncBoardsToSettings()
        if needsFetch { Task { await refresh() } }
    }

    private func save(_ newValue: UserSettings) {
        settingsStore.save(newValue)
        settings = newValue
        syncBoardsToSettings()
    }

    /// Removing or reordering teams shouldn't wait on the network.
    private func syncBoardsToSettings() {
        let order = Dictionary(settings.favourites.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        withAnimation(.smooth) {
            dashboards = dashboards
                .filter { order[$0.id] != nil }
                .sorted { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
            failures = failures.filter { order[$0.id] != nil }
        }
    }

    private func observeCloud() {
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadFromICloud() }
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}
