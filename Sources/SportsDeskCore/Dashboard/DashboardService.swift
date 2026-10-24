import Foundation

public struct DashboardService: Sendable {
    public var catalog: TeamCatalog
    public var providers: [League: any LeagueDashboardProviding]

    public init(catalog: TeamCatalog = .shared, providers: [League: any LeagueDashboardProviding]) {
        self.catalog = catalog
        self.providers = providers
    }

    public static func live(
        http: HTTPClient = HTTPClient(),
        lineProvider: any LineCombinationProviding = DailyFaceoffLineProvider(),
        injuryProvider: any InjuryProviding = ESPNInjuryProvider()
    ) -> DashboardService {
        DashboardService(providers: [
            .nhl: NHLProvider(client: http, lineProvider: lineProvider),
            .nfl: NFLProvider(client: http, injuryProvider: injuryProvider)
        ])
    }

    public func dashboard(for favourite: FavouriteTeam) async throws -> TeamDashboard {
        let id = favourite.teamID
        let team = try catalog.required(id)
        guard let provider = providers[id.league] else {
            throw SportsDeskError.unsupportedLeague(id.league)
        }
        return try await provider.dashboard(for: team)
    }

    /// Loads every favourite concurrently; results keep the user's order.
    public func dashboards(for favourites: [FavouriteTeam]) async -> DashboardLoadResult {
        let outcomes = await withTaskGroup(of: (Int, Result<TeamDashboard, any Error>).self) { group in
            for (index, favourite) in favourites.enumerated() {
                group.addTask {
                    do { return (index, .success(try await dashboard(for: favourite))) }
                    catch { return (index, .failure(error)) }
                }
            }
            var collected: [(Int, Result<TeamDashboard, any Error>)] = []
            for await outcome in group { collected.append(outcome) }
            return collected.sorted { $0.0 < $1.0 }
        }
        var result = DashboardLoadResult()
        for (index, outcome) in outcomes {
            switch outcome {
            case .success(let board):
                result.boards.append(board)
            case .failure(let error):
                let favourite = favourites[index]
                let name = catalog.team(for: favourite.teamID)?.displayName ?? favourite.id
                result.failures.append(DashboardFailure(favourite: favourite, teamName: name, message: error.localizedDescription))
            }
        }
        return result
    }

    public func dashboards(for settings: UserSettings) async -> DashboardLoadResult {
        await dashboards(for: settings.favourites)
    }
}

public struct DashboardFailure: Hashable, Sendable, Identifiable {
    public var favourite: FavouriteTeam
    public var teamName: String
    public var message: String
    public var id: String { favourite.id }
}

public struct DashboardLoadResult: Sendable {
    public var boards: [TeamDashboard] = []
    public var failures: [DashboardFailure] = []
    public var errors: [String] { failures.map { "\($0.teamName): \($0.message)" } }
}
