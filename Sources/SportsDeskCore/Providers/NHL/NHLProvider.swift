import Foundation

public protocol LeagueDashboardProviding: Sendable {
    var league: League { get }
    func dashboard(for team: TeamSummary) async throws -> TeamDashboard
}

public struct NHLProvider: LeagueDashboardProviding {
    public var league: League { .nhl }
    public var client: HTTPClient
    public var lineProvider: any LineCombinationProviding
    public var catalog: TeamCatalog

    public init(
        client: HTTPClient = HTTPClient(),
        lineProvider: any LineCombinationProviding = DailyFaceoffLineProvider(),
        catalog: TeamCatalog = .shared
    ) {
        self.client = client
        self.lineProvider = lineProvider
        self.catalog = catalog
    }

    public func dashboard(for team: TeamSummary) async throws -> TeamDashboard {
        async let standingsResponse = client.getJSON(NHLStandingsResponse.self, url: NHLAPI.standingsNow)
        async let clubStats = client.getJSON(NHLClubStatsResponse.self, url: NHLAPI.clubStats(team.abbreviation))
        async let week = client.getJSON(NHLWeekScheduleResponse.self, url: NHLAPI.clubWeek(team.abbreviation))
        async let summary = optionalJSON(NHLTeamSummaryResponse.self, url: NHLAPI.teamSummary)
        async let lines = lineProvider.lines(for: team)

        let standings = try await standingsResponse
        let snapshot = Self.standingsSnapshot(standings, favourite: team, catalog: catalog)
        let stats = try await clubStats
        let schedule = try await week
        let game = try await hydrate(game: Self.pickGame(from: schedule.games, team: team), team: team)
        let teamStats = Self.teamStats(team: team, summary: await summary, standings: snapshot, club: stats)

        return TeamDashboard(
            team: team,
            standings: snapshot,
            teamStats: teamStats,
            game: game,
            lines: await lines
        )
    }

    func hydrate(game: NHLScheduleGame?, team: TeamSummary) async throws -> GameSnapshot? {
        guard let game else { return nil }
        var landing: NHLLandingResponse?
        var boxscore: NHLBoxscoreResponse?
        if let url = NHLAPI.landing(game.id) {
            landing = try? await client.getJSON(NHLLandingResponse.self, url: url)
        }
        let state = (landing?.gameState ?? game.gameState ?? "").uppercased()
        if ["LIVE", "CRIT", "FINAL", "OFF"].contains(state), let url = NHLAPI.boxscore(game.id) {
            boxscore = try? await client.getJSON(NHLBoxscoreResponse.self, url: url)
        }
        return Self.gameSnapshot(schedule: game, landing: landing, boxscore: boxscore, team: team)
    }

    private func optionalJSON<T: Decodable>(_ type: T.Type, url: URL?) async -> T? {
        guard let url else { return nil }
        return try? await client.getJSON(type, url: url)
    }

    static func pickGame(from games: [NHLScheduleGame], team: TeamSummary) -> NHLScheduleGame? {
        let live = games.first { ["LIVE", "CRIT"].contains(($0.gameState ?? "").uppercased()) }
        if let live { return live }
        let upcoming = games
            .filter { ["FUT", "PRE"].contains(($0.gameState ?? "").uppercased()) }
            .sorted { ($0.startTimeUTC ?? "") < ($1.startTimeUTC ?? "") }
        if let next = upcoming.first { return next }
        return games.last { ["OFF", "FINAL"].contains(($0.gameState ?? "").uppercased()) } ?? games.last
    }

    static func standingsSnapshot(_ response: NHLStandingsResponse, favourite: TeamSummary, catalog: TeamCatalog) -> StandingsSnapshot {
        let rows: [StandingRow] = response.standings.compactMap { row in
            let code = row.teamAbbrev.value.uppercased()
            let team = catalog.team(for: TeamID(league: .nhl, code: code)) ?? TeamSummary(
                id: TeamID(league: .nhl, code: code),
                displayName: row.teamName.value,
                shortName: row.teamName.value,
                city: row.teamName.value,
                abbreviation: code,
                conference: row.conferenceName,
                division: row.divisionName,
                primaryHex: "333333",
                secondaryHex: "FFFFFF",
                logoURL: URL(string: row.teamLogo ?? "")
            )
            return StandingRow(
                team: team,
                rank: row.leagueSequence ?? 0,
                gamesPlayed: row.gamesPlayed ?? 0,
                record: "\(row.wins ?? 0)-\(row.losses ?? 0)-\(row.otLosses ?? 0)",
                pointsOrPct: "\(row.points ?? 0) pts",
                pointsFor: "\(row.goalFor ?? 0)",
                pointsAgainst: "\(row.goalAgainst ?? 0)",
                streak: row.streakCode.flatMap { code in
                    row.streakCount.map { "\(code)\($0)" }
                },
                isFavourite: code == favourite.abbreviation
            )
        }
        let ranked = rows.sorted { $0.rank < $1.rank }
        let conference = ranked.filter { $0.team.conference == favourite.conference }
            .sorted { conferenceRank(for: $0, in: response) < conferenceRank(for: $1, in: response) }
        let division = ranked.filter { $0.team.division == favourite.division }
            .sorted { divisionRank(for: $0, in: response) < divisionRank(for: $1, in: response) }
        return StandingsSnapshot(
            league: .nhl,
            asOf: DateParser.parse(response.standingsDateTimeUtc),
            leagueRows: ranked,
            conferenceRows: conference,
            divisionRows: division,
            conferenceName: favourite.conference,
            divisionName: favourite.division
        )
    }

    private static func conferenceRank(for row: StandingRow, in response: NHLStandingsResponse) -> Int {
        response.standings.first { $0.teamAbbrev.value.uppercased() == row.team.abbreviation }?.conferenceSequence ?? row.rank
    }

    private static func divisionRank(for row: StandingRow, in response: NHLStandingsResponse) -> Int {
        response.standings.first { $0.teamAbbrev.value.uppercased() == row.team.abbreviation }?.divisionSequence ?? row.rank
    }

    static func teamStats(
        team: TeamSummary,
        summary: NHLTeamSummaryResponse?,
        standings: StandingsSnapshot,
        club: NHLClubStatsResponse
    ) -> TeamStatBlock {
        let row = standings.leagueRows.first(where: { $0.team.abbreviation == team.abbreviation })
        let summaryRow = summary?.data.first {
            ($0.teamFullName ?? "").localizedCaseInsensitiveContains(team.shortName)
                || ($0.teamFullName ?? "").localizedCaseInsensitiveContains(team.city)
        }
        var items: [StatLine] = []
        if let row {
            items.append(StatLine(label: "Record", value: row.record, detail: row.pointsOrPct))
            items.append(StatLine(label: "GF-GA", value: "\(row.pointsFor)-\(row.pointsAgainst)"))
        }
        if let summaryRow {
            items.append(StatLine(label: "GF/G", value: oneDecimal(summaryRow.goalsForPerGame)))
            items.append(StatLine(label: "GA/G", value: oneDecimal(summaryRow.goalsAgainstPerGame)))
            items.append(StatLine(label: "PP%", value: percent(summaryRow.powerPlayPct)))
            items.append(StatLine(label: "PK%", value: percent(summaryRow.penaltyKillPct)))
            items.append(StatLine(label: "FO%", value: percent(summaryRow.faceoffWinPct)))
        }
        let skaters = club.skaters
            .sorted { ($0.points ?? 0) > ($1.points ?? 0) }
            .prefix(8)
            .map { skater in
                PlayerStat(
                    id: String(skater.playerId),
                    name: "\(skater.firstName.value) \(skater.lastName.value)",
                    position: skater.positionCode,
                    headshotURL: URL(string: skater.headshot ?? ""),
                    line: "\(skater.points ?? 0) pts",
                    secondary: "\(skater.goals ?? 0)G \(skater.assists ?? 0)A in \(skater.gamesPlayed ?? 0) GP"
                )
            }
        let goalies = club.goalies.map { goalie in
            PlayerStat(
                id: String(goalie.playerId),
                name: "\(goalie.firstName.value) \(goalie.lastName.value)",
                position: "G",
                headshotURL: URL(string: goalie.headshot ?? ""),
                line: String(format: "%.2f GAA", goalie.goalsAgainstAverage ?? 0),
                secondary: String(format: ".%03.0f SV%% · %d-%d-%d", (goalie.savePercentage ?? 0) * 1000, goalie.wins ?? 0, goalie.losses ?? 0, goalie.overtimeLosses ?? 0)
            )
        }
        return TeamStatBlock(headline: row.map { "\($0.record), \($0.pointsOrPct)" } ?? "Season stats", items: items, players: Array(skaters) + goalies)
    }

    static func gameSnapshot(
        schedule: NHLScheduleGame,
        landing: NHLLandingResponse?,
        boxscore: NHLBoxscoreResponse?,
        team: TeamSummary
    ) -> GameSnapshot {
        let away = landing?.awayTeam ?? schedule.awayTeam
        let home = landing?.homeTeam ?? schedule.homeTeam
        let isHome = home.abbrev.uppercased() == team.abbreviation
        let opponent = isHome ? away : home
        let state = (landing?.gameState ?? schedule.gameState ?? "").uppercased()
        let phase: GamePhase
        switch state {
        case "LIVE", "CRIT": phase = .live
        case "OFF", "FINAL": phase = .final
        case "FUT", "PRE": phase = .upcoming
        default: phase = .unknown
        }
        let period = landing?.periodDescriptor ?? schedule.periodDescriptor
        let clock = landing?.clock ?? schedule.clock
        var periodLabel: String?
        if let number = period?.number {
            let kind = period?.periodType == "OT" ? "OT" : (period?.periodType == "SO" ? "SO" : "P\(number)")
            periodLabel = kind
        }
        if clock?.inIntermission == true {
            periodLabel = [periodLabel, "INT"].compactMap { $0 }.joined(separator: " ")
        }
        let broadcasts = (landing?.tvBroadcasts ?? schedule.tvBroadcasts ?? []).compactMap { item -> BroadcastInfo? in
            guard let network = item.network, !network.isEmpty else { return nil }
            return BroadcastInfo(network: network, market: item.market)
        }
        var notes: [String] = []
        if let matchup = landing?.matchup?.skaterComparison {
            let context = matchup.contextLabel?.replacingOccurrences(of: "_", with: " ")
            if let context { notes.append(context.capitalized) }
            for leader in matchup.leaders ?? [] {
                let awayName = [leader.awayLeader?.firstName?.value, leader.awayLeader?.lastName?.value].compactMap { $0 }.joined(separator: " ")
                let homeName = [leader.homeLeader?.firstName?.value, leader.homeLeader?.lastName?.value].compactMap { $0 }.joined(separator: " ")
                if !awayName.isEmpty || !homeName.isEmpty {
                    notes.append("\(leader.category ?? "leader"): \(away.abbrev) \(awayName) vs \(home.abbrev) \(homeName)")
                }
            }
        }
        var scoring: [String] = []
        for periodBlock in landing?.summary?.scoring ?? [] {
            let label = periodBlock.periodDescriptor?.number.map { "P\($0)" } ?? "Period"
            for goal in periodBlock.goals {
                scoring.append("\(label) \(goal.teamAbbrev?.value ?? "") \(goal.name?.value ?? "Goal") (\(goal.strength ?? "ev"))")
            }
        }
        let boxPlayers = boxPlayers(from: boxscore, favouriteIsHome: isHome)
        let headline: String
        switch phase {
        case .live:
            headline = [periodLabel, clock?.timeRemaining].compactMap { $0 }.joined(separator: " · ")
        case .final:
            headline = "Final"
        case .upcoming:
            headline = DateParser.parse(landing?.startTimeUTC ?? schedule.startTimeUTC).map { DateParser.weekdayTime(date: $0) } ?? "Upcoming"
        case .unknown:
            headline = state
        }
        return GameSnapshot(
            id: String(schedule.id),
            phase: phase,
            start: DateParser.parse(landing?.startTimeUTC ?? schedule.startTimeUTC),
            opponentName: [opponent.placeName?.value, opponent.commonName?.value].compactMap { $0 }.joined(separator: " "),
            opponentCode: opponent.abbrev,
            opponentLogoURL: URL(string: opponent.logo ?? ""),
            isHome: isHome,
            venue: landing?.venue?.value ?? schedule.venue?.value,
            venueCity: landing?.venueLocation?.value,
            broadcasts: broadcasts,
            homeScore: home.score,
            awayScore: away.score,
            homeCode: home.abbrev,
            awayCode: away.abbrev,
            periodLabel: periodLabel,
            clock: clock?.timeRemaining,
            detailHeadline: headline,
            notes: notes,
            scoringSummary: scoring,
            boxscorePlayers: boxPlayers
        )
    }

    private static func boxPlayers(from boxscore: NHLBoxscoreResponse?, favouriteIsHome: Bool) -> [PlayerStat] {
        guard let team = favouriteIsHome ? boxscore?.playerByGameStats?.homeTeam : boxscore?.playerByGameStats?.awayTeam else {
            return []
        }
        let skaters = (team.forwards ?? []) + (team.defense ?? [])
        let top = skaters.sorted { ($0.points ?? 0) > ($1.points ?? 0) }.prefix(6).map { skater in
            PlayerStat(
                id: String(skater.playerId),
                name: skater.name.value,
                position: skater.position,
                line: "\(skater.points ?? 0) pts",
                secondary: "\(skater.goals ?? 0)G \(skater.assists ?? 0)A · \(skater.toi ?? "")"
            )
        }
        let goalies = (team.goalies ?? []).map { goalie in
            PlayerStat(
                id: String(goalie.playerId),
                name: goalie.name.value,
                position: "G",
                line: goalie.saveShotsAgainst ?? "—",
                secondary: (goalie.starter == true) ? "Starter" : nil
            )
        }
        return Array(top) + goalies
    }
}

enum NHLAPI {
    static let standingsNow = URL(string: "https://api-web.nhle.com/v1/standings/now")!
    static func clubStats(_ team: String) -> URL { URL(string: "https://api-web.nhle.com/v1/club-stats/\(team)/now")! }
    static func clubWeek(_ team: String) -> URL { URL(string: "https://api-web.nhle.com/v1/club-schedule/\(team)/week/now")! }
    static func landing(_ id: Int) -> URL? { URL(string: "https://api-web.nhle.com/v1/gamecenter/\(id)/landing") }
    static func boxscore(_ id: Int) -> URL? { URL(string: "https://api-web.nhle.com/v1/gamecenter/\(id)/boxscore") }
    static let teamSummary: URL? = {
        var components = URLComponents(string: "https://api.nhle.com/stats/rest/en/team/summary")
        components?.queryItems = [URLQueryItem(name: "cayenneExp", value: "gameTypeId=2 and seasonId=20262027")]
        return components?.url
    }()
}
