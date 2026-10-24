import Foundation
import Testing
@testable import SportsDeskCore

@Suite("NHL decoding")
struct NHLDecodingTests {
    @Test func standingsIncludeLeafsAndConferences() throws {
        let response = try FixtureLoader.decode(NHLStandingsResponse.self, "nhl_standings.json")
        #expect(response.standings.contains { $0.teamAbbrev.value == "TOR" })
        let tor = try #require(response.standings.first { $0.teamAbbrev.value == "TOR" })
        #expect(tor.conferenceName == "Eastern")
        #expect(tor.divisionName == "Atlantic")
        #expect((tor.points ?? 0) > 0)
    }

    @Test func clubStatsDecodeSkatersAndGoalies() throws {
        let response = try FixtureLoader.decode(NHLClubStatsResponse.self, "nhl_club_stats.json")
        #expect(!response.skaters.isEmpty)
        #expect(!response.goalies.isEmpty)
        #expect(response.skaters[0].lastName.value == "Tavares" || !response.skaters[0].lastName.value.isEmpty)
    }

    @Test func weekScheduleHasBroadcastsAndUTCStart() throws {
        let response = try FixtureLoader.decode(NHLWeekScheduleResponse.self, "nhl_club_week.json")
        #expect(!response.games.isEmpty)
        let first = response.games[0]
        #expect(DateParser.parse(first.startTimeUTC) != nil)
        #expect(!(first.tvBroadcasts ?? []).isEmpty)
    }

    @Test func landingPreviewAndFinalBoxscore() throws {
        let preview = try FixtureLoader.decode(NHLLandingResponse.self, "nhl_landing_preview.json")
        #expect(preview.gameState == "FUT")
        #expect(preview.awayTeam.abbrev == "TOR")
        let final = try FixtureLoader.decode(NHLLandingResponse.self, "nhl_landing_final.json")
        #expect(final.awayTeam.score != nil)
        let box = try FixtureLoader.decode(NHLBoxscoreResponse.self, "nhl_boxscore_final.json")
        #expect(box.playerByGameStats?.homeTeam?.forwards?.isEmpty == false)
    }
}

@Suite("ESPN decoding")
struct ESPNDecodingTests {
    @Test func teamAndNextEvent() throws {
        let response = try FixtureLoader.decode(ESPNTeamResponse.self, "espn_gb_team.json")
        #expect(response.team.abbreviation == "GB")
        #expect(response.team.id.value == "9")
        #expect(!(response.team.nextEvent ?? []).isEmpty)
    }

    @Test func divisionStandings() throws {
        let response = try FixtureLoader.decode(ESPNStandingsResponse.self, "espn_nfl_standings.json")
        let nfc = try #require(response.children?.first { $0.abbreviation == "NFC" })
        let north = try #require(nfc.children?.first { $0.name == "NFC North" })
        let codes = (north.standings?.entries ?? []).compactMap { $0.team.abbreviation }
        #expect(codes.contains("GB"))
    }

    @Test func statisticsDepthAndInjuries() throws {
        let stats = try FixtureLoader.decode(ESPNStatisticsResponse.self, "espn_gb_statistics.json")
        #expect((stats.results?.stats?.categories?.count ?? 0) > 0)
        let depth = try FixtureLoader.decode(ESPNDepthChartResponse.self, "espn_gb_depthchart.json")
        #expect((depth.depthchart?.count ?? 0) > 0)
        let injuries = try FixtureLoader.decode(ESPNInjuriesResponse.self, "espn_nfl_injuries.json")
        #expect(injuries.injuries.first?.id.value == "9")
        #expect((injuries.injuries.first?.injuries.count ?? 0) > 0)
    }

    @Test func scheduleParsesGameTimes() throws {
        let response = try FixtureLoader.decode(ESPNScheduleResponse.self, "espn_gb_schedule.json")
        let dated = (response.events ?? []).compactMap { DateParser.parse($0.date) }
        #expect(!dated.isEmpty)
    }
}
