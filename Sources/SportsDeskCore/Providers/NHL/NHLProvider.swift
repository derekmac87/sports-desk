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
        // Standings are required; everything else degrades to empty sections (off-season, feed hiccups).
        async let standingsResponse = client.getJSON(NHLStandingsResponse.self, url: NHLAPI.standingsNow)
        async let clubStats = optionalJSON(NHLClubStatsResponse.self, url: NHLAPI.clubStats(team.abbreviation))
        async let week = optionalJSON(NHLWeekScheduleResponse.self, url: NHLAPI.clubWeek(team.abbreviation))
        async let lines = lineProvider.lines(for: team)

        let standings = try await standingsResponse
        let snapshot = Self.standingsSnapshot(standings, favourite: team, catalog: catalog)
        let stats = await clubStats
        let seasonID = stats?.season?.value ?? Season.nhlSeasonID(for: Date())
        async let summary = optionalJSON(NHLTeamSummaryResponse.self, url: NHLAPI.teamSummary(season: seasonID))
        let schedule = await week
        let game = await hydrate(game: Self.pickGame(from: schedule?.games ?? [], team: team), team: team)
        let teamStats = Self.teamStats(
            team: team,
            summary: await summary,
            standings: snapshot,
            club: stats ?? NHLClubStatsResponse(skaters: [], goalies: [])
        )

        return TeamDashboard(
            team: team,
            standings: snapshot,
            teamStats: teamStats,
            game: game,
            lines: await lines
        )
    }

    func hydrate(game: NHLScheduleGame?, team: TeamSummary) async -> GameSnapshot? {
        guard let game else { return nil }
        let scheduleState = (game.gameState ?? "").uppercased()
        async let landing = optionalJSON(NHLLandingResponse.self, url: NHLAPI.landing(game.id))
        async let boxscore: NHLBoxscoreResponse? = Self.hasStarted(scheduleState)
            ? optionalJSON(NHLBoxscoreResponse.self, url: NHLAPI.boxscore(game.id))
            : nil
        return Self.gameSnapshot(schedule: game, landing: await landing, boxscore: await boxscore, team: team, catalog: catalog)
    }

    private func optionalJSON<T: Decodable>(_ type: T.Type, url: URL?) async -> T? {
        guard let url else { return nil }
        return try? await client.getJSON(type, url: url)
    }

    private static func hasStarted(_ state: String) -> Bool {
        ["LIVE", "CRIT", "FINAL", "OFF"].contains(state)
    }

    /// Live game first, then a game that finished within `recentWindow`, then the next scheduled game.
    static func pickGame(
        from games: [NHLScheduleGame],
        team: TeamSummary,
        now: Date = Date(),
        recentWindow: TimeInterval = 12 * 3600
    ) -> NHLScheduleGame? {
        func state(_ game: NHLScheduleGame) -> String { (game.gameState ?? "").uppercased() }
        func start(_ game: NHLScheduleGame) -> Date { DateParser.parse(game.startTimeUTC) ?? .distantPast }

        if let live = games.first(where: { ["LIVE", "CRIT"].contains(state($0)) }) { return live }
        let finished = games.filter { ["OFF", "FINAL"].contains(state($0)) }.sorted { start($0) < start($1) }
        if let recent = finished.last, now.timeIntervalSince(start(recent)) < recentWindow {
            return recent
        }
        let upcoming = games.filter { ["FUT", "PRE"].contains(state($0)) }.sorted { start($0) < start($1) }
        return upcoming.first ?? finished.last ?? games.last
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
                logoURL: TeamCatalog.logoURL(league: .nhl, abbreviation: code)
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
        // Match on id or full name only: city alone would confuse NYR/NYI.
        let summaryRow = summary?.data.first { $0.teamId.map(String.init) == team.providerCode }
            ?? summary?.data.first { ($0.teamFullName ?? "").localizedCaseInsensitiveCompare(team.displayName) == .orderedSame }
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
                line: goalie.goalsAgainstAverage.map { String(format: "%.2f GAA", $0) } ?? "—",
                secondary: "\(savePct(goalie.savePercentage)) SV% · \(goalie.wins ?? 0)-\(goalie.losses ?? 0)-\(goalie.overtimeLosses ?? 0)"
            )
        }
        return TeamStatBlock(headline: row.map { "\($0.record), \($0.pointsOrPct)" } ?? "Season stats", items: items, players: Array(skaters) + goalies)
    }

    static func gameSnapshot(
        schedule: NHLScheduleGame,
        landing: NHLLandingResponse?,
        boxscore: NHLBoxscoreResponse?,
        team: TeamSummary,
        catalog: TeamCatalog = .shared
    ) -> GameSnapshot {
        let away = landing?.awayTeam ?? schedule.awayTeam
        let home = landing?.homeTeam ?? schedule.homeTeam
        let isHome = home.abbrev.uppercased() == team.abbreviation
        let opponent = isHome ? away : home
        let opponentTeam = catalog.team(for: TeamID(league: .nhl, code: opponent.abbrev))
        let state = (landing?.gameState ?? schedule.gameState ?? "").uppercased()
        let phase: GamePhase
        switch state {
        case "LIVE", "CRIT": phase = .live
        case "OFF", "FINAL": phase = .final
        case "FUT", "PRE": phase = .upcoming
        default: phase = .unknown
        }
        let period = landing?.periodDescriptor ?? schedule.periodDescriptor
        let clock = phase == .live ? (landing?.clock ?? schedule.clock) : nil
        // Schedules carry a period-1 descriptor for future games; only label started games.
        var periodLabel = (phase == .live || phase == .final) ? period.map(Self.periodLabel) : nil
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
            let label = periodBlock.periodDescriptor.map(Self.periodLabel) ?? "Period"
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
            headline = ["OT", "SO"].contains(period?.periodType ?? "") ? "Final/\(period?.periodType ?? "")" : "Final"
        case .upcoming:
            headline = DateParser.parse(landing?.startTimeUTC ?? schedule.startTimeUTC).map { DateParser.weekdayTime(date: $0) } ?? "Upcoming"
        case .unknown:
            headline = state.isEmpty ? "Game" : state.capitalized
        }
        let feedName = [opponent.placeName?.value, opponent.commonName?.value].compactMap { $0 }.joined(separator: " ")
        return GameSnapshot(
            id: String(schedule.id),
            phase: phase,
            start: DateParser.parse(landing?.startTimeUTC ?? schedule.startTimeUTC),
            opponentName: opponentTeam?.displayName ?? (feedName.isEmpty ? opponent.abbrev : feedName),
            opponentCode: opponent.abbrev,
            opponentLogoURL: opponentTeam?.logoURL ?? TeamCatalog.logoURL(league: .nhl, abbreviation: opponent.abbrev),
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
                secondary: ["\(skater.goals ?? 0)G \(skater.assists ?? 0)A", skater.toi].compactMap { $0 }.joined(separator: " · ")
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

    /// P1–P3, OT (2OT, 3OT… in the playoffs) and SO.
    static func periodLabel(_ period: NHLPeriod) -> String {
        let number = period.number ?? 0
        switch period.periodType?.uppercased() {
        case "SO": return "SO"
        case "OT": return number > 4 ? "\(number - 3)OT" : "OT"
        default: return number > 0 ? "P\(number)" : "—"
        }
    }

    private static func savePct(_ value: Double?) -> String {
        guard let value else { return "—" }
        let text = String(format: "%.3f", value)
        return text.hasPrefix("0") ? String(text.dropFirst()) : text
    }
}

enum NHLAPI {
    static let standingsNow = URL(string: "https://api-web.nhle.com/v1/standings/now")!
    static func clubStats(_ team: String) -> URL { URL(string: "https://api-web.nhle.com/v1/club-stats/\(team)/now")! }
    static func clubWeek(_ team: String) -> URL { URL(string: "https://api-web.nhle.com/v1/club-schedule/\(team)/week/now")! }
    static func landing(_ id: Int) -> URL? { URL(string: "https://api-web.nhle.com/v1/gamecenter/\(id)/landing") }
    static func boxscore(_ id: Int) -> URL? { URL(string: "https://api-web.nhle.com/v1/gamecenter/\(id)/boxscore") }
    static func teamSummary(season: String) -> URL? {
        var components = URLComponents(string: "https://api.nhle.com/stats/rest/en/team/summary")
        components?.queryItems = [URLQueryItem(name: "cayenneExp", value: "gameTypeId=2 and seasonId=\(season)")]
        return components?.url
    }
}
