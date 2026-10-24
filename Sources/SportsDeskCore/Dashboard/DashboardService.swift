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

    public func dashboards(for settings: UserSettings) async -> (boards: [TeamDashboard], errors: [String]) {
        var boards: [TeamDashboard] = []
        var errors: [String] = []
        for favourite in settings.favourites {
            do {
                boards.append(try await dashboard(for: favourite))
            } catch {
                errors.append("\(favourite.id): \(error.localizedDescription)")
            }
        }
        return (boards, errors)
    }
}
