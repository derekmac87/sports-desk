import Foundation

public struct NFLProvider: LeagueDashboardProviding {
    public var league: League { .nfl }
    public var client: HTTPClient
    public var injuryProvider: any InjuryProviding
    public var catalog: TeamCatalog

    public init(
        client: HTTPClient = HTTPClient(),
        injuryProvider: any InjuryProviding = ESPNInjuryProvider(),
        catalog: TeamCatalog = .shared
    ) {
        self.client = client
        self.injuryProvider = injuryProvider
        self.catalog = catalog
    }

    public func dashboard(for team: TeamSummary) async throws -> TeamDashboard {
        let slug = team.abbreviation.lowercased()
        async let teamJSON = client.getJSON(ESPNTeamResponse.self, url: ESPNAPI.team(slug))
        async let scheduleJSON = client.getJSON(ESPNScheduleResponse.self, url: ESPNAPI.schedule(slug))
        async let standingsJSON = client.getJSON(ESPNStandingsResponse.self, url: ESPNAPI.standings)
        async let statsJSON = client.getJSON(ESPNStatisticsResponse.self, url: ESPNAPI.statistics(slug))
        async let depthJSON = optionalJSON(ESPNDepthChartResponse.self, url: ESPNAPI.depthChart(slug))
        async let rosterJSON = optionalJSON(ESPNRosterResponse.self, url: ESPNAPI.roster(slug))
        async let leadersJSON = optionalJSON(ESPNLeadersResponse.self, url: ESPNAPI.leaders(team.providerCode))
        async let injuries = injuryProvider.injuries(for: team)

        let teamPayload = try await teamJSON
        let schedule = try await scheduleJSON
        let standings = try await standingsJSON
        let stats = try await statsJSON
        let snapshot = Self.standingsSnapshot(standings, favourite: team, catalog: catalog)
        let event = Self.pickEvent(team: teamPayload.team, schedule: schedule.events ?? [])
        var game = event.map { Self.gameSnapshot(event: $0, team: team) }
        if let event, shouldHydrate(event), let summary = try? await client.getJSON(ESPNSummaryResponse.self, url: ESPNAPI.summary(event.id.value)) {
            game = Self.merge(game: game, summary: summary, team: team)
        }
        let roster = await rosterJSON
        let leaders = await leadersJSON
        let depth = await depthJSON.map { Self.depthChart($0) }
        let teamStats = Self.teamStats(stats: stats, roster: roster, leaders: leaders, standings: snapshot, team: team)

        return TeamDashboard(
            team: team,
            standings: snapshot,
            teamStats: teamStats,
            game: game,
            depthChart: depth,
            injuries: await injuries
        )
    }

    private func optionalJSON<T: Decodable>(_ type: T.Type, url: URL) async -> T? {
        try? await client.getJSON(type, url: url)
    }

    private func shouldHydrate(_ event: ESPNEvent) -> Bool {
        let state = event.competitions?.first?.status?.type?.state
        return state == "in" || state == "post"
    }

    static func pickEvent(team: ESPNTeam, schedule: [ESPNEvent]) -> ESPNEvent? {
        let events = schedule.isEmpty ? (team.nextEvent ?? []) : schedule
        if let live = events.first(where: { $0.competitions?.first?.status?.type?.state == "in" }) {
            return live
        }
        if let upcoming = events.first(where: { $0.competitions?.first?.status?.type?.state == "pre" }) {
            return upcoming
        }
        return events.last(where: { $0.competitions?.first?.status?.type?.state == "post" }) ?? team.nextEvent?.first
    }

    static func standingsSnapshot(_ response: ESPNStandingsResponse, favourite: TeamSummary, catalog: TeamCatalog) -> StandingsSnapshot {
        var leagueRows: [StandingRow] = []
        var conferenceRows: [StandingRow] = []
        var divisionRows: [StandingRow] = []

        func rows(from group: ESPNStandingsGroup, rankByWins: Bool = true) -> [StandingRow] {
            let entries = group.standings?.entries ?? []
            return entries.enumerated().map { index, entry in
                row(from: entry, fallbackRank: index + 1, favourite: favourite, catalog: catalog)
            }.sorted {
                if rankByWins {
                    return wins(from: $0) > wins(from: $1)
                }
                return $0.rank < $1.rank
            }
        }

        for conference in response.children ?? [] {
            let conferenceName = conference.abbreviation ?? conference.name
            if let children = conference.children, !children.isEmpty {
                var allInConference: [StandingRow] = []
                for division in children {
                    let mapped = rows(from: division)
                    if division.name == favourite.division || division.abbreviation == favourite.division {
                        divisionRows = mapped
                    }
                    allInConference.append(contentsOf: mapped)
                }
                if conferenceName == favourite.conference || conference.name == favourite.conference {
                    conferenceRows = allInConference.sorted { wins(from: $0) > wins(from: $1) }
                }
                leagueRows.append(contentsOf: allInConference)
            } else {
                let mapped = rows(from: conference)
                if conferenceName == favourite.conference || conference.name == favourite.conference {
                    conferenceRows = mapped
                }
                leagueRows.append(contentsOf: mapped)
            }
        }

        leagueRows.sort { wins(from: $0) > wins(from: $1) }
        if divisionRows.isEmpty {
            divisionRows = leagueRows.filter { $0.team.division == favourite.division }
        }
        if conferenceRows.isEmpty {
            conferenceRows = leagueRows.filter { $0.team.conference == favourite.conference }
        }
        return StandingsSnapshot(
            league: .nfl,
            leagueRows: ranked(leagueRows),
            conferenceRows: ranked(conferenceRows),
            divisionRows: ranked(divisionRows),
            conferenceName: favourite.conference,
            divisionName: favourite.division
        )
    }

    private static func ranked(_ rows: [StandingRow]) -> [StandingRow] {
        rows.enumerated().map { index, row in
            var copy = row
            copy = StandingRow(
                team: row.team,
                rank: index + 1,
                gamesPlayed: row.gamesPlayed,
                record: row.record,
                pointsOrPct: row.pointsOrPct,
                pointsFor: row.pointsFor,
                pointsAgainst: row.pointsAgainst,
                streak: row.streak,
                isFavourite: row.isFavourite
            )
            return copy
        }
    }

    private static func wins(from row: StandingRow) -> Int {
        Int(row.record.split(separator: "-").first ?? "0") ?? 0
    }

    private static func row(from entry: ESPNStandingEntry, fallbackRank: Int, favourite: TeamSummary, catalog: TeamCatalog) -> StandingRow {
        let code = (entry.team.abbreviation ?? "").uppercased()
        let team = catalog.team(for: TeamID(league: .nfl, code: code)) ?? TeamSummary(
            id: TeamID(league: .nfl, code: code.isEmpty ? entry.team.id.value : code),
            displayName: entry.team.displayName ?? code,
            shortName: entry.team.name ?? code,
            city: entry.team.location ?? "",
            abbreviation: code,
            primaryHex: "333333",
            secondaryHex: "FFFFFF"
        )
        func stat(_ name: String) -> ESPNNamedStat? {
            entry.stats?.first { $0.name == name }
        }
        let wins = Int(stat("wins")?.value ?? 0)
        let losses = Int(stat("losses")?.value ?? 0)
        let ties = Int(stat("ties")?.value ?? 0)
        let record = stat("overall")?.displayValue ?? (ties > 0 ? "\(wins)-\(losses)-\(ties)" : "\(wins)-\(losses)")
        return StandingRow(
            team: team,
            rank: fallbackRank,
            gamesPlayed: wins + losses + ties,
            record: record,
            pointsOrPct: stat("winPercent")?.displayValue ?? stat("winPercent")?.value.map { String(format: ".%03.0f", $0 * 1000) } ?? "—",
            pointsFor: stat("pointsFor")?.displayValue ?? "—",
            pointsAgainst: stat("pointsAgainst")?.displayValue ?? "—",
            streak: stat("streak")?.displayValue,
            isFavourite: code == favourite.abbreviation
        )
    }

    static func teamStats(
        stats: ESPNStatisticsResponse,
        roster: ESPNRosterResponse?,
        leaders: ESPNLeadersResponse?,
        standings: StandingsSnapshot,
        team: TeamSummary
    ) -> TeamStatBlock {
        var items: [StatLine] = []
        if let row = standings.leagueRows.first(where: { $0.team.abbreviation == team.abbreviation }) {
            items.append(StatLine(label: "Record", value: row.record, detail: row.pointsOrPct))
            items.append(StatLine(label: "PF-PA", value: "\(row.pointsFor)-\(row.pointsAgainst)"))
            if let streak = row.streak { items.append(StatLine(label: "Streak", value: streak)) }
        }
        if let summary = stats.team?.recordSummary {
            items.append(StatLine(label: "Season", value: summary, detail: stats.team?.standingSummary))
        }
        let wanted = ["passingYards", "rushingYards", "receivingYards", "totalTouchdowns", "sacks", "interceptions", "fieldGoalsMade"]
        for category in stats.results?.stats?.categories ?? [] {
            for stat in category.stats ?? [] where wanted.contains(stat.name ?? "") {
                items.append(StatLine(label: stat.displayName ?? stat.name ?? "Stat", value: stat.displayValue ?? "—"))
            }
        }

        let namesByID = rosterNames(roster)
        let players: [PlayerStat] = (leaders?.categories ?? []).compactMap { category in
            guard let leader = category.leaders?.first, let ref = leader.athlete?.ref else { return nil }
            let id = athleteID(from: ref)
            return PlayerStat(
                id: id ?? (category.name ?? UUID().uuidString),
                name: id.flatMap { namesByID[$0] } ?? (category.displayName ?? "Leader"),
                position: category.displayName,
                line: leader.displayValue ?? "",
                secondary: category.name
            )
        }
        return TeamStatBlock(
            headline: items.first?.value ?? "Season stats",
            items: items,
            players: players
        )
    }

    static func depthChart(_ response: ESPNDepthChartResponse) -> DepthChartReport {
        var units: [String: [DepthSlot]] = [:]
        var starters: [DepthSlot] = []
        for unit in response.depthchart ?? [] {
            let unitName = unit.name ?? "Unit"
            var slots: [DepthSlot] = []
            let positions = unit.positions ?? [:]
            for key in positions.keys.sorted() {
                guard let position = positions[key] else { continue }
                let label = position.position?.abbreviation?.uppercased() ?? key.uppercased()
                if let starter = position.athletes?.first, let name = starter.displayName {
                    let slot = DepthSlot(position: label, playerName: name, unitName: unitName)
                    slots.append(slot)
                    if unitName.localizedCaseInsensitiveContains("WR") || unitName.localizedCaseInsensitiveContains("Offense") || unitName.localizedCaseInsensitiveContains("3WR") || unitName.localizedCaseInsensitiveContains("Base") {
                        starters.append(slot)
                    }
                }
            }
            units[unitName] = slots
        }
        if starters.isEmpty {
            starters = units.values.flatMap { $0 }
        }
        return DepthChartReport(sourceName: "ESPN Depth Chart", starters: starters, units: units)
    }

    static func gameSnapshot(event: ESPNEvent, team: TeamSummary) -> GameSnapshot {
        let competition = event.competitions?.first
        let state = competition?.status?.type?.state
        let phase: GamePhase
        switch state {
        case "in": phase = .live
        case "post": phase = .final
        case "pre": phase = .upcoming
        default: phase = .unknown
        }
        let competitors = competition?.competitors ?? []
        let home = competitors.first { $0.homeAway == "home" }
        let away = competitors.first { $0.homeAway == "away" }
        let isHome = home?.team?.abbreviation?.uppercased() == team.abbreviation
        let opponent = isHome ? away : home
        let broadcasts: [BroadcastInfo] = (competition?.broadcasts ?? []).compactMap { item in
            if let name = item.media?.shortName { return BroadcastInfo(network: name, market: item.market?.type) }
            if let name = item.names?.first { return BroadcastInfo(network: name, market: item.market?.type) }
            return nil
        }
        let period: String?
        if let number = competition?.status?.period, number > 0 {
            period = "Q\(number)"
        } else {
            period = nil
        }
        let headline: String
        switch phase {
        case .live:
            headline = [period, competition?.status?.displayClock, competition?.situation?.downDistanceText]
                .compactMap { $0 }.joined(separator: " · ")
        case .final:
            headline = competition?.status?.type?.shortDetail ?? "Final"
        case .upcoming:
            headline = DateParser.parse(event.date).map { DateParser.weekdayTime(date: $0) }
                ?? competition?.status?.type?.shortDetail
                ?? "Upcoming"
        case .unknown:
            headline = competition?.status?.type?.description ?? "Game"
        }
        return GameSnapshot(
            id: event.id.value,
            phase: phase,
            start: DateParser.parse(event.date ?? competition?.date),
            opponentName: opponent?.team?.displayName ?? event.name ?? "Opponent",
            opponentCode: opponent?.team?.abbreviation ?? "",
            opponentLogoURL: URL(string: opponent?.team?.logo ?? ""),
            isHome: isHome,
            venue: competition?.venue?.fullName,
            venueCity: [competition?.venue?.address?.city, competition?.venue?.address?.state].compactMap { $0 }.joined(separator: ", "),
            broadcasts: broadcasts,
            homeScore: Int(home?.score?.value ?? ""),
            awayScore: Int(away?.score?.value ?? ""),
            homeCode: home?.team?.abbreviation ?? "",
            awayCode: away?.team?.abbreviation ?? "",
            periodLabel: period,
            clock: competition?.status?.displayClock,
            detailHeadline: headline,
            notes: [competition?.situation?.possessionText].compactMap { $0 }
        )
    }

    static func merge(game: GameSnapshot?, summary: ESPNSummaryResponse, team: TeamSummary) -> GameSnapshot? {
        let resolved = game ?? summary.header.map { gameSnapshot(event: $0, team: team) }
        guard var game = resolved else { return nil }
        if let venue = summary.gameInfo?.venue?.fullName {
            game.venue = venue
        }
        if game.broadcasts.isEmpty {
            game.broadcasts = (summary.broadcasts ?? []).compactMap { item in
                item.media?.shortName.map { BroadcastInfo(network: $0, market: item.market?.type) }
            }
        }
        return game
    }

    private static func rosterNames(_ roster: ESPNRosterResponse?) -> [String: String] {
        var map: [String: String] = [:]
        for group in roster?.athletes ?? [] {
            for athlete in group.items ?? [] {
                if let id = athlete.id?.value, let name = athlete.displayName {
                    map[id] = name
                }
            }
        }
        return map
    }

    private static func athleteID(from ref: String) -> String? {
        let parts = ref.split(separator: "/").map(String.init)
        if let index = parts.firstIndex(of: "athletes"), parts.indices.contains(index + 1) {
            return parts[index + 1].split(separator: "?").first.map(String.init)
        }
        return nil
    }
}

enum ESPNAPI {
    static func team(_ slug: String) -> URL { URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/\(slug)")! }
    static func schedule(_ slug: String) -> URL { URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/\(slug)/schedule")! }
    static func statistics(_ slug: String) -> URL { URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/\(slug)/statistics")! }
    static func depthChart(_ slug: String) -> URL { URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/\(slug)/depthcharts")! }
    static func roster(_ slug: String) -> URL { URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/\(slug)/roster")! }
    static func summary(_ event: String) -> URL { URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary?event=\(event)")! }
    static func leaders(_ teamID: String) -> URL {
        URL(string: "https://sports.core.api.espn.com/v2/sports/football/leagues/nfl/seasons/2026/types/2/teams/\(teamID)/leaders")!
    }
    static let standings = URL(string: "https://site.api.espn.com/apis/v2/sports/football/nfl/standings?level=3")!
}
