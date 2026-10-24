import Foundation
import Testing
@testable import SportsDeskCore

@Suite("Settings")
struct SettingsTests {
    @Test func defaultsAreLeafsAndPackers() {
        let settings = UserSettings.default
        #expect(settings.favourites.map(\.id) == ["nhl:TOR", "nfl:GB"])
    }

    @Test func storeRoundTripAndCloudWins() {
        let local = MemoryKeyValueStore()
        let cloud = MemoryKeyValueStore()
        let store = SettingsStore(local: local, cloud: cloud)
        #expect(store.load() == .default)

        let updated = UserSettings(favourites: [FavouriteTeam(league: .nhl, code: "BOS")])
        store.save(updated)
        #expect(store.load().favourites.map(\.code) == ["BOS"])

        let remote = UserSettings(favourites: [FavouriteTeam(league: .nfl, code: "DET")])
        let data = try! JSONEncoder().encode(remote)
        cloud.set(data: data, forKey: SettingsStore.storageKey)
        #expect(store.load().favourites.map(\.code) == ["DET"])
    }

    @Test func emptyFavouritesFallBackToDefaults() {
        let local = MemoryKeyValueStore()
        let store = SettingsStore(local: local)
        store.save(UserSettings(favourites: []))
        #expect(store.load() == .default)
    }
}

@Suite("Mapping")
struct MappingTests {
    @Test func nhlStandingsAndGameSelection() throws {
        let response = try FixtureLoader.decode(NHLStandingsResponse.self, "nhl_standings.json")
        let team = try #require(TeamCatalog.shared.team(for: TeamID(league: .nhl, code: "TOR")))
        let snapshot = NHLProvider.standingsSnapshot(response, favourite: team, catalog: .shared)
        #expect(snapshot.divisionName == "Atlantic")
        #expect(snapshot.conferenceName == "Eastern")
        #expect(snapshot.divisionRows.contains { $0.team.abbreviation == "TOR" })
        #expect(snapshot.leagueRows.contains { $0.isFavourite })

        let week = try FixtureLoader.decode(NHLWeekScheduleResponse.self, "nhl_club_week.json")
        let game = try #require(NHLProvider.pickGame(from: week.games, team: team))
        #expect(["FUT", "PRE", "LIVE", "CRIT"].contains(game.gameState ?? ""))
        let landing = try FixtureLoader.decode(NHLLandingResponse.self, "nhl_landing_preview.json")
        let snapshotGame = NHLProvider.gameSnapshot(schedule: game, landing: landing, boxscore: nil, team: team)
        #expect(snapshotGame.opponentCode == "EDM")
        #expect(snapshotGame.phase == .upcoming)
        #expect(snapshotGame.start != nil)
        #expect(!snapshotGame.broadcasts.isEmpty)
    }

    @Test func dailyFaceoffLinesParseFromNextData() throws {
        let html = try FixtureLoader.data("dailyfaceoff_tor.html")
        let report = try DailyFaceoffLineProvider.parse(data: html)
        #expect(report.isUnavailable == false)
        #expect(report.forwardLines.count == 2)
        #expect(report.defensePairs.count == 2)
        #expect(report.goalies.count == 2)
        #expect(report.forwardLines[0].players.contains { $0.name.contains("Matthews") })
    }

    @Test func dailyFaceoffUnavailableOnGarbage() {
        let report = DailyFaceoffLineProvider.parseRoot(["nope": true], sourceName: "Daily Faceoff")
        #expect(report.isUnavailable)
    }

    @Test func espnInjuriesMarkKeyStatuses() throws {
        let response = try FixtureLoader.decode(ESPNInjuriesResponse.self, "espn_nfl_injuries.json")
        let team = try #require(TeamCatalog.shared.team(for: TeamID(league: .nfl, code: "GB")))
        let report = ESPNInjuryProvider.map(response, team: team)
        #expect(!report.keyItems.isEmpty)
        #expect(report.items.contains { $0.status.lowercased() == "questionable" })
        #expect(report.keyItems.allSatisfy { $0.status.lowercased() != "active" })
        #expect(report.items.contains { $0.injury != nil && $0.position != nil })
    }

    @Test func nflStandingsAndDepthChart() throws {
        let standings = try FixtureLoader.decode(ESPNStandingsResponse.self, "espn_nfl_standings.json")
        let team = try #require(TeamCatalog.shared.team(for: TeamID(league: .nfl, code: "GB")))
        let snapshot = NFLProvider.standingsSnapshot(standings, favourite: team, catalog: .shared)
        #expect(snapshot.divisionName == "NFC North")
        #expect(snapshot.divisionRows.contains { $0.team.abbreviation == "GB" })
        #expect(snapshot.conferenceRows.contains { $0.team.abbreviation == "DET" })

        let depth = try FixtureLoader.decode(ESPNDepthChartResponse.self, "espn_gb_depthchart.json")
        let chart = NFLProvider.depthChart(depth)
        #expect(!chart.starters.isEmpty)
        #expect(chart.starters.contains { $0.position == "QB" || $0.playerName.contains(" ") })
    }

    @Test func serviceRejectsUnknownLeague() async {
        let yankees = TeamSummary(
            id: TeamID(league: League(rawValue: "mlb"), code: "NYY"),
            displayName: "New York Yankees",
            shortName: "Yankees",
            city: "New York",
            abbreviation: "NYY",
            primaryHex: "132448",
            secondaryHex: "C4CED4"
        )
        let service = DashboardService(catalog: TeamCatalog(teams: [yankees]), providers: [:])
        await #expect(throws: SportsDeskError.unsupportedLeague(League(rawValue: "mlb"))) {
            _ = try await service.dashboard(for: FavouriteTeam(league: League(rawValue: "mlb"), code: "NYY"))
        }
    }

    @Test func catalogHasDefaultTeams() {
        #expect(TeamCatalog.shared.team(for: TeamID(league: .nhl, code: "TOR"))?.displayName == "Toronto Maple Leafs")
        #expect(TeamCatalog.shared.team(for: TeamID(league: .nfl, code: "GB"))?.displayName == "Green Bay Packers")
        #expect(TeamCatalog.shared.teams(in: .nhl).count == 32)
        #expect(TeamCatalog.shared.teams(in: .nfl).count == 32)
    }

    @Test func dateParserHandlesEspnAndNHL() throws {
        #expect(DateParser.parse("2026-10-24T23:00:00Z") != nil)
        #expect(DateParser.parse("2026-10-25T20:25Z") != nil)
        let date = try #require(DateParser.parse("2026-10-25T20:25Z"))
        let text = DateParser.display(date: date, timeZone: TimeZone(identifier: "America/Toronto")!)
        #expect(text.contains("2026") || text.contains("Oct"))
    }
}

@Suite("Fixture-backed providers")
struct ProviderIntegrationTests {
    @Test func nhlProviderBuildsDashboardFromFixtures() async throws {
        let transport = try fixtureTransport(nhl: true)
        let lines = DailyFaceoffLineProvider(client: HTTPClient(transport: transport))
        let provider = NHLProvider(client: HTTPClient(transport: transport), lineProvider: lines)
        let team = try #require(TeamCatalog.shared.team(for: TeamID(league: .nhl, code: "TOR")))
        let board = try await provider.dashboard(for: team)
        #expect(board.team.abbreviation == "TOR")
        #expect(!board.standings.leagueRows.isEmpty)
        #expect(!board.teamStats.players.isEmpty)
        #expect(board.game?.opponentCode == "EDM")
        #expect(board.lines?.isUnavailable == false)
    }

    @Test func nflProviderIncludesInjuries() async throws {
        let transport = try fixtureTransport(nhl: false)
        let injuries = ESPNInjuryProvider(client: HTTPClient(transport: transport))
        let provider = NFLProvider(client: HTTPClient(transport: transport), injuryProvider: injuries)
        let team = try #require(TeamCatalog.shared.team(for: TeamID(league: .nfl, code: "GB")))
        let board = try await provider.dashboard(for: team)
        #expect(board.team.abbreviation == "GB")
        #expect((board.injuries?.keyItems.count ?? 0) > 0)
        #expect(board.depthChart?.isUnavailable != true)
        #expect(board.game != nil)
    }
}

private func fixtureTransport(nhl: Bool) throws -> FixtureHTTPSession {
    var responses: [String: Data] = [:]
    func put(_ hostPath: String, _ file: String) throws {
        responses[hostPath] = try FixtureLoader.data(file)
    }
    if nhl {
        try put("api-web.nhle.com/v1/standings/now", "nhl_standings.json")
        try put("api-web.nhle.com/v1/club-stats/TOR/now", "nhl_club_stats.json")
        try put("api-web.nhle.com/v1/club-schedule/TOR/week/now", "nhl_club_week.json")
        try put("api.nhle.com/stats/rest/en/team/summary?cayenneExp=gameTypeId=2 and seasonId=20262027", "nhl_team_summary.json")
        try put("api-web.nhle.com/v1/gamecenter/2026020176/landing", "nhl_landing_preview.json")
        try put("www.dailyfaceoff.com/teams/toronto-maple-leafs/line-combinations/", "dailyfaceoff_tor.html")
    } else {
        try put("site.api.espn.com/apis/site/v2/sports/football/nfl/teams/gb", "espn_gb_team.json")
        try put("site.api.espn.com/apis/site/v2/sports/football/nfl/teams/gb/schedule", "espn_gb_schedule.json")
        try put("site.api.espn.com/apis/v2/sports/football/nfl/standings?level=3", "espn_nfl_standings.json")
        try put("site.api.espn.com/apis/site/v2/sports/football/nfl/teams/gb/statistics", "espn_gb_statistics.json")
        try put("site.api.espn.com/apis/site/v2/sports/football/nfl/teams/gb/depthcharts", "espn_gb_depthchart.json")
        try put("site.api.espn.com/apis/site/v2/sports/football/nfl/teams/gb/roster", "espn_gb_roster.json")
        try put("sports.core.api.espn.com/v2/sports/football/leagues/nfl/seasons/2026/types/2/teams/9/leaders", "espn_gb_leaders.json")
        try put("site.api.espn.com/apis/site/v2/sports/football/nfl/injuries", "espn_nfl_injuries.json")
        try put("site.api.espn.com/apis/site/v2/sports/football/nfl/summary?event=401873020", "espn_game_summary.json")
    }
    return FixtureHTTPSession(responses: responses)
}
