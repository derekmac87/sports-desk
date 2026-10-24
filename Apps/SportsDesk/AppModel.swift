import Combine
import Foundation
import SportsDeskCore

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: UserSettings
    @Published var dashboards: [TeamDashboard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    let catalog = TeamCatalog.shared
    let settingsStore: SettingsStore
    let service: DashboardService

    init(
        settingsStore: SettingsStore = .production(),
        service: DashboardService = .live()
    ) {
        self.settingsStore = settingsStore
        self.service = service
        self.settings = settingsStore.load()
        observeCloud()
    }

    func bootstrap() async {
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        settings = settingsStore.load()
        let result = await service.dashboards(for: settings)
        dashboards = result.boards
        if !result.errors.isEmpty {
            errorMessage = result.errors.joined(separator: "\n")
        } else if result.boards.isEmpty {
            errorMessage = "No favourite teams yet. Add the Leafs, Packers, or anyone else in Settings."
        }
        lastUpdated = Date()
        isLoading = false
    }

    func saveSettings(_ newValue: UserSettings) {
        settings = newValue
        settingsStore.save(newValue)
    }

    func addFavourite(_ team: TeamSummary) {
        guard !settings.favourites.contains(where: { $0.id == team.id.description }) else { return }
        var next = settings
        next.favourites.append(FavouriteTeam(league: team.id.league, code: team.abbreviation))
        saveSettings(next)
        Task { await refresh() }
    }

    func removeFavourite(_ team: FavouriteTeam) {
        var next = settings
        next.favourites.removeAll { $0.id == team.id }
        saveSettings(next)
    }

    func moveFavourite(from source: IndexSet, to destination: Int) {
        var next = settings
        next.favourites.move(fromOffsets: source, toOffset: destination)
        saveSettings(next)
    }

    private func observeCloud() {
        #if os(iOS) || os(tvOS) || os(macOS)
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.settings = self?.settingsStore.applyRemoteIfNewer() ?? .default
            }
        }
        NSUbiquitousKeyValueStore.default.synchronize()
        #endif
    }
}
