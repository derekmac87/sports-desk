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

    @Test func defaultsOnlyOnFirstRunAndEmptyListIsKept() {
        let store = SettingsStore(local: MemoryKeyValueStore())
        #expect(store.load() == .default)
        store.save(UserSettings(favourites: []))
        #expect(store.load().favourites.isEmpty)
    }

    @Test func unknownAndDuplicateTeamsAreDropped() {
        let store = SettingsStore(local: MemoryKeyValueStore())
        store.save(UserSettings(favourites: [
            FavouriteTeam(league: .nhl, code: "TOR"),
            FavouriteTeam(league: .nhl, code: "tor"),
            FavouriteTeam(league: .nhl, code: "ARI")
        ]))
        #expect(store.load().favourites.map(\.id) == ["nhl:TOR"])
    }

    @Test func settingsDecodeWithMissingKeys() throws {
        let json = Data(#"{"favourites":[{"league":"nfl","code":"DET"}]}"#.utf8)
        let settings = try JSONDecoder().decode(UserSettings.self, from: json)
        #expect(settings.favourites.map(\.code) == ["DET"])
        #expect(settings.useDeviceTimeZone)
    }
}

@Suite("Fixes")
struct FixTests {
    private func team(_ league: League, _ code: String) throws -> TeamSummary {
        try #require(TeamCatalog.shared.team(for: TeamID(league: league, code: code)))
    }

    @Test func espnScheduleScoresDecodeFromObjects() throws {
        let schedule = try FixtureLoader.decode(ESPNScheduleResponse.self, "espn_gb_schedule.json")
        let final = try #require(schedule.events?.first { $0.competitions?.first?.status?.type?.state == "post" })
        let game = NFLProvider.gameSnapshot(event: final, team: try team(.nfl, "GB"))
        #expect(game.phase == .final)
        #expect(game.teamScore == 23)
        #expect(game.opponentScore == 13)
        #expect(game.outcome == "W")
        #expect(game.opponentLogoURL?.pathExtension == "png")
        #expect(game.periodLabel == "Q4")
        #expect(game.clock == nil)
    }

    @Test func nflPicksRecentFinalThenNextGame() throws {
        let schedule = try FixtureLoader.decode(ESPNScheduleResponse.self, "espn_gb_schedule.json")
        let events = schedule.events ?? []
        let rightAfter = try #require(DateParser.parse("2026-10-19T04:00:00Z"))
        #expect(NFLProvider.pickEvent(nextEvents: [], schedule: events, now: rightAfter)?.competitions?.first?.status?.type?.state == "post")
        let midweek = try #require(DateParser.parse("2026-10-22T12:00:00Z"))
        let next = try #require(NFLProvider.pickEvent(nextEvents: [], schedule: events, now: midweek))
        #expect(next.competitions?.first?.status?.type?.state == "pre")
        #expect(NFLProvider.gameSnapshot(event: next, team: try team(.nfl, "GB")).homeScore == nil)
    }

    @Test func nflPeriodLabels() {
        #expect(NFLProvider.periodLabel(0) == nil)
        #expect(NFLProvider.periodLabel(4) == "Q4")
        #expect(NFLProvider.periodLabel(5) == "OT")
        #expect(NFLProvider.periodLabel(6) == "2OT")
    }

    @Test func nflStandingsOrderedByWinPct() throws {
        let standings = try FixtureLoader.decode(ESPNStandingsResponse.self, "espn_nfl_standings.json")
        let snapshot = NFLProvider.standingsSnapshot(standings, favourite: try team(.nfl, "GB"), catalog: .shared)
        let pcts = snapshot.leagueRows.map(NFLProvider.winPct)
        #expect(pcts == pcts.sorted(by: >))
        #expect(snapshot.leagueRows.map(\.rank) == Array(1...snapshot.leagueRows.count))
        #expect(NFLProvider.winPct(StandingRow(team: try team(.nfl, "GB"), rank: 1, gamesPlayed: 3, record: "1-1-1", pointsOrPct: "", pointsFor: "", pointsAgainst: "")) == 0.5)
    }

    @Test func nhlFinalHasScoresAndNoStaleClock() throws {
        let landing = try FixtureLoader.decode(NHLLandingResponse.self, "nhl_landing_final.json")
        let week = try FixtureLoader.decode(NHLWeekScheduleResponse.self, "nhl_club_week.json")
        let game = NHLProvider.gameSnapshot(schedule: week.games[0], landing: landing, boxscore: nil, team: try team(.nhl, "TOR"))
        #expect(game.phase == .final)
        #expect(game.isHome)
        #expect(game.outcome == "W")
        #expect(game.opponentName == "New York Rangers")
        #expect(game.opponentLogoURL?.absoluteString.hasSuffix("/nyr.png") == true)
        #expect(game.clock == nil)
        #expect(game.detailHeadline == "Final")
    }

    @Test func nhlUpcomingGameHasNoPeriod() throws {
        let week = try FixtureLoader.decode(NHLWeekScheduleResponse.self, "nhl_club_week.json")
        let game = NHLProvider.gameSnapshot(schedule: week.games[0], landing: nil, boxscore: nil, team: try team(.nhl, "TOR"))
        #expect(game.phase == .upcoming)
        #expect(game.periodLabel == nil)
        #expect(game.homeScore == nil && game.awayScore == nil)
    }

    @Test func nhlPeriodLabels() {
        #expect(NHLProvider.periodLabel(NHLPeriod(number: 2, periodType: "REG")) == "P2")
        #expect(NHLProvider.periodLabel(NHLPeriod(number: 4, periodType: "OT")) == "OT")
        #expect(NHLProvider.periodLabel(NHLPeriod(number: 6, periodType: "OT")) == "3OT")
        #expect(NHLProvider.periodLabel(NHLPeriod(number: 5, periodType: "SO")) == "SO")
    }

    @Test func nhlPicksRecentFinalOverNextGame() throws {
        var finished = try FixtureLoader.decode(NHLWeekScheduleResponse.self, "nhl_club_week.json").games
        finished[0].gameState = "OFF"
        let start = try #require(DateParser.parse(finished[0].startTimeUTC))
        let tor = try team(.nhl, "TOR")
        #expect(NHLProvider.pickGame(from: finished, team: tor, now: start.addingTimeInterval(3 * 3600))?.id == finished[0].id)
        #expect(NHLProvider.pickGame(from: finished, team: tor, now: start.addingTimeInterval(20 * 3600))?.id == finished[1].id)
    }

    @Test func nhlSummaryMatchesByTeamIDNotCity() throws {
        let rangers = try team(.nhl, "NYR")
        let summary = NHLTeamSummaryResponse(data: [
            NHLTeamSummaryRow(teamFullName: "New York Islanders", teamId: 2, powerPlayPct: 0.10),
            NHLTeamSummaryRow(teamFullName: "New York Rangers", teamId: 3, powerPlayPct: 0.25)
        ])
        let standings = StandingsSnapshot(league: .nhl, leagueRows: [], conferenceRows: [], divisionRows: [])
        let block = NHLProvider.teamStats(team: rangers, summary: summary, standings: standings, club: NHLClubStatsResponse(skaters: [], goalies: []))
        #expect(block.items.first { $0.label == "PP%" }?.value == "25.0%")
    }

    @Test func seasonIdentifiers() throws {
        let october = try #require(DateParser.parse("2026-10-24T18:00:00Z"))
        let february = try #require(DateParser.parse("2027-02-07T23:30:00Z"))
        let july = try #require(DateParser.parse("2027-07-01T12:00:00Z"))
        #expect(Season.nhlSeasonID(for: october) == "20262027")
        #expect(Season.nhlSeasonID(for: february) == "20262027")
        #expect(Season.nhlSeasonID(for: july) == "20262027")
        #expect(Season.nflSeasonYear(for: october) == 2026)
        #expect(Season.nflSeasonYear(for: february) == 2026)
    }

    @Test func logosArePNG() {
        for team in TeamCatalog.shared.teams {
            #expect(team.logoURL?.pathExtension == "png", "\(team.id)")
        }
        #expect(TeamCatalog.logoURL(league: .nhl, abbreviation: "TBL")?.lastPathComponent == "tb.png")
    }

    @Test func injuriesSortedBySeverity() throws {
        let response = try FixtureLoader.decode(ESPNInjuriesResponse.self, "espn_nfl_injuries.json")
        let report = ESPNInjuryProvider.map(response, team: try team(.nfl, "GB"))
        let ranks = report.items.map { ESPNInjuryProvider.severity(status: $0.status) }
        #expect(ranks == ranks.sorted())
    }

    @Test func errorsHaveReadableMessages() {
        #expect(SportsDeskError.network("HTTP 503").localizedDescription.contains("HTTP 503"))
    }

    @Test func serviceLoadsConcurrentlyInOrderAndReportsFailures() async {
        struct Stub: LeagueDashboardProviding {
            var league: League
            func dashboard(for team: TeamSummary) async throws -> TeamDashboard {
                if team.abbreviation == "BOS" { throw SportsDeskError.network("HTTP 500") }
                try await Task.sleep(nanoseconds: team.abbreviation == "TOR" ? 50_000_000 : 1_000_000)
                return TeamDashboard(
                    team: team,
                    standings: StandingsSnapshot(league: league, leagueRows: [], conferenceRows: [], divisionRows: []),
                    teamStats: TeamStatBlock(headline: "", items: [])
                )
            }
        }
        let service = DashboardService(providers: [.nhl: Stub(league: .nhl), .nfl: Stub(league: .nfl)])
        let result = await service.dashboards(for: [
            FavouriteTeam(league: .nhl, code: "TOR"),
            FavouriteTeam(league: .nhl, code: "BOS"),
            FavouriteTeam(league: .nfl, code: "GB")
        ])
        #expect(result.boards.map(\.team.abbreviation) == ["TOR", "GB"])
        #expect(result.failures.map(\.teamName) == ["Boston Bruins"])
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
        #expect(board.teamStats.items.contains { $0.label == "PP%" })
    }

    @Test func nhlProviderSurvivesMissingOptionalFeeds() async throws {
        let standings = try FixtureLoader.data("nhl_standings.json")
        let transport = FixtureHTTPSession(responses: ["api-web.nhle.com/v1/standings/now": standings])
        let provider = NHLProvider(client: HTTPClient(transport: transport), lineProvider: UnavailableLineProvider(reason: "test"))
        let team = try #require(TeamCatalog.shared.team(for: TeamID(league: .nhl, code: "TOR")))
        let board = try await provider.dashboard(for: team)
        #expect(board.game == nil)
        #expect(!board.standings.divisionRows.isEmpty)
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
        #expect(board.depthChart?.unitOrder.isEmpty == false)
        #expect(board.game?.opponentCode == "DET")
        #expect(Set(board.teamStats.players.map(\.id)).count == board.teamStats.players.count)
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
