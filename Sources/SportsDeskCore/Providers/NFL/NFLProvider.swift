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
        // Standings are required; everything else degrades to empty sections (off-season, feed hiccups).
        async let standingsJSON = client.getJSON(ESPNStandingsResponse.self, url: ESPNAPI.standings)
        async let teamJSON = optionalJSON(ESPNTeamResponse.self, url: ESPNAPI.team(slug))
        async let scheduleJSON = optionalJSON(ESPNScheduleResponse.self, url: ESPNAPI.schedule(slug))
        async let statsJSON = optionalJSON(ESPNStatisticsResponse.self, url: ESPNAPI.statistics(slug))
        async let depthJSON = optionalJSON(ESPNDepthChartResponse.self, url: ESPNAPI.depthChart(slug))
        async let rosterJSON = optionalJSON(ESPNRosterResponse.self, url: ESPNAPI.roster(slug))
        async let injuries = injuryProvider.injuries(for: team)

        let standings = try await standingsJSON
        let snapshot = Self.standingsSnapshot(standings, favourite: team, catalog: catalog)
        let schedule = await scheduleJSON
        let season = schedule?.season?.year ?? Season.nflSeasonYear(for: Date())
        async let leadersJSON = optionalJSON(ESPNLeadersResponse.self, url: ESPNAPI.leaders(team.providerCode, season: season))

        let event = Self.pickEvent(nextEvents: (await teamJSON)?.team.nextEvent ?? [], schedule: schedule?.events ?? [])
        var game = event.map { Self.gameSnapshot(event: $0, team: team, catalog: catalog) }
        if let event, shouldHydrate(event),
           let summary = await optionalJSON(ESPNSummaryResponse.self, url: ESPNAPI.summary(event.id.value)) {
            game = Self.merge(game: game, summary: summary, team: team, catalog: catalog)
        }
        let teamStats = Self.teamStats(
            stats: await statsJSON ?? ESPNStatisticsResponse(),
            roster: await rosterJSON,
            leaders: await leadersJSON,
            standings: snapshot,
            team: team
        )

        return TeamDashboard(
            team: team,
            standings: snapshot,
            teamStats: teamStats,
            game: game,
            depthChart: await depthJSON.map { Self.depthChart($0) },
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

    /// Live game first, then one that finished within `recentWindow`, then the next scheduled game.
    /// `nextEvents` (team endpoint) covers playoff games the regular-season schedule omits.
    static func pickEvent(
        nextEvents: [ESPNEvent],
        schedule: [ESPNEvent],
        now: Date = Date(),
        recentWindow: TimeInterval = 18 * 3600
    ) -> ESPNEvent? {
        var seen = Set<String>()
        let events = (nextEvents + schedule)
            .filter { seen.insert($0.id.value).inserted }
            .sorted { start($0) < start($1) }
        func state(_ event: ESPNEvent) -> String? { event.competitions?.first?.status?.type?.state }

        if let live = events.first(where: { state($0) == "in" }) { return live }
        let finished = events.filter { state($0) == "post" }
        if let recent = finished.last, now.timeIntervalSince(start(recent)) < recentWindow {
            return recent
        }
        return events.first { state($0) == "pre" && start($0) > now.addingTimeInterval(-6 * 3600) }
            ?? events.first { state($0) == "pre" }
            ?? finished.last
    }

    private static func start(_ event: ESPNEvent) -> Date {
        DateParser.parse(event.date ?? event.competitions?.first?.date) ?? .distantPast
    }

    static func standingsSnapshot(_ response: ESPNStandingsResponse, favourite: TeamSummary, catalog: TeamCatalog) -> StandingsSnapshot {
        var leagueRows: [StandingRow] = []
        var conferenceRows: [StandingRow] = []
        var divisionRows: [StandingRow] = []

        // ESPN lists each group in tiebreaker order, so keep that order among equal win percentages.
        func rows(from group: ESPNStandingsGroup) -> [StandingRow] {
            let entries = group.standings?.entries ?? []
            return byWinPct(entries.enumerated().map { index, entry in
                row(from: entry, fallbackRank: index + 1, favourite: favourite, catalog: catalog)
            })
        }

        for conference in response.children ?? [] {
            let isFavouriteConference = conference.abbreviation == favourite.conference || conference.name == favourite.conference
            if let children = conference.children, !children.isEmpty {
                var allInConference: [StandingRow] = []
                for division in children {
                    let mapped = rows(from: division)
                    if division.name == favourite.division || division.abbreviation == favourite.division {
                        divisionRows = mapped
                    }
                    allInConference.append(contentsOf: mapped)
                }
                if isFavouriteConference {
                    conferenceRows = byWinPct(allInConference)
                }
                leagueRows.append(contentsOf: allInConference)
            } else {
                let mapped = rows(from: conference)
                if isFavouriteConference {
                    conferenceRows = mapped
                }
                leagueRows.append(contentsOf: mapped)
            }
        }

        leagueRows = byWinPct(leagueRows)
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

    private static func byWinPct(_ rows: [StandingRow]) -> [StandingRow] {
        rows.enumerated()
            .sorted { lhs, rhs in
                let left = winPct(lhs.element), right = winPct(rhs.element)
                if left != right { return left > right }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func ranked(_ rows: [StandingRow]) -> [StandingRow] {
        rows.enumerated().map { index, row in
            var copy = row
            copy.rank = index + 1
            return copy
        }
    }

    /// From the "W-L(-T)" record; ties count as half a win.
    static func winPct(_ row: StandingRow) -> Double {
        let parts = row.record.split(separator: "-").compactMap { Double($0) }
        guard parts.count >= 2 else { return 0 }
        let ties = parts.count > 2 ? parts[2] : 0
        let games = parts[0] + parts[1] + ties
        return games > 0 ? (parts[0] + ties / 2) / games : 0
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
            secondaryHex: "FFFFFF",
            logoURL: TeamCatalog.logoURL(league: .nfl, abbreviation: code)
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
        var seenStats = Set<String>()
        for category in stats.results?.stats?.categories ?? [] {
            for stat in category.stats ?? [] where wanted.contains(stat.name ?? "") {
                // Names repeat across categories (e.g. interceptions thrown vs. made); keep ids unique.
                let id = "\(category.name ?? "")-\(stat.name ?? "")"
                guard seenStats.insert(id).inserted else { continue }
                items.append(StatLine(id: id, label: stat.displayName ?? stat.name ?? "Stat", value: stat.displayValue ?? "—"))
            }
        }

        let rosterByID = rosterAthletes(roster)
        let leaderCategories = ["passingLeader", "rushingLeader", "receivingLeader", "sacks", "interceptions", "totalTackles"]
        let categories = (leaders?.categories ?? []).filter { leaderCategories.contains($0.name ?? "") }
        let players: [PlayerStat] = (categories.isEmpty ? (leaders?.categories ?? []) : categories).compactMap { category in
            guard let leader = category.leaders?.first, let ref = leader.athlete?.ref, let id = athleteID(from: ref) else { return nil }
            let athlete = rosterByID[id]
            return PlayerStat(
                id: "\(category.name ?? "leader")-\(id)",
                name: athlete?.displayName ?? (category.displayName ?? "Leader"),
                position: athlete?.position?.abbreviation,
                headshotURL: athlete?.headshot?.href.flatMap(URL.init(string:)),
                line: leader.displayValue ?? "",
                secondary: category.displayName
            )
        }
        return TeamStatBlock(
            headline: items.first?.value ?? "Season stats",
            items: items,
            players: players
        )
    }

    private static let depthPositionOrder = [
        "qb", "rb", "fb", "wr1", "wr2", "wr3", "te", "lt", "lg", "c", "rg", "rt",
        "lde", "ldt", "nt", "rdt", "rde", "wlb", "lilb", "mlb", "rilb", "slb", "lcb", "rcb", "nb", "ss", "fs",
        "pk", "p", "h", "ls", "pr", "kr"
    ]

    static func depthChart(_ response: ESPNDepthChartResponse) -> DepthChartReport {
        var units: [String: [DepthSlot]] = [:]
        var order: [String] = []
        var starters: [DepthSlot] = []
        for unit in response.depthchart ?? [] {
            let unitName = unit.name ?? "Unit"
            var slots: [DepthSlot] = []
            let positions = unit.positions ?? [:]
            let keys = positions.keys.sorted { lhs, rhs in
                let left = depthPositionOrder.firstIndex(of: lhs.lowercased()) ?? Int.max
                let right = depthPositionOrder.firstIndex(of: rhs.lowercased()) ?? Int.max
                return left == right ? lhs < rhs : left < right
            }
            for key in keys {
                guard let position = positions[key] else { continue }
                let label = position.position?.abbreviation?.uppercased() ?? key.uppercased()
                if let starter = position.athletes?.first, let name = starter.displayName {
                    let slot = DepthSlot(id: "\(unitName)-\(key)", position: label, playerName: name, unitName: unitName)
                    slots.append(slot)
                    if unitName.localizedCaseInsensitiveContains("WR") || unitName.localizedCaseInsensitiveContains("Offense") || unitName.localizedCaseInsensitiveContains("Base") {
                        starters.append(slot)
                    }
                }
            }
            if units[unitName] == nil { order.append(unitName) }
            units[unitName] = slots
        }
        if starters.isEmpty {
            starters = order.flatMap { units[$0] ?? [] }
        }
        return DepthChartReport(sourceName: "ESPN Depth Chart", starters: starters, units: units, unitOrder: order)
    }

    static func gameSnapshot(event: ESPNEvent, team: TeamSummary, catalog: TeamCatalog = .shared) -> GameSnapshot {
        let competition = event.competitions?.first
        let status = competition?.status
        let phase: GamePhase
        switch status?.type?.state {
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
        let opponentCode = opponent?.team?.abbreviation ?? ""
        let opponentTeam = catalog.team(for: TeamID(league: .nfl, code: opponentCode))
        let broadcasts: [BroadcastInfo] = (competition?.broadcasts ?? []).compactMap { item in
            if let name = item.media?.shortName { return BroadcastInfo(network: name, market: item.market?.type) }
            if let name = item.names?.first { return BroadcastInfo(network: name, market: item.market?.type) }
            return nil
        }
        let period = (phase == .live || phase == .final) ? status?.period.flatMap(periodLabel) : nil
        let clock = phase == .live ? status?.displayClock : nil
        let headline: String
        switch phase {
        case .live:
            // shortDetail covers "Halftime", "End of 3rd" and "2:00 - 4th", which period + clock can't.
            headline = [status?.type?.shortDetail ?? [period, clock].compactMap { $0 }.joined(separator: " "), competition?.situation?.downDistanceText]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        case .final:
            headline = status?.type?.shortDetail ?? "Final"
        case .upcoming:
            headline = DateParser.parse(event.date).map { DateParser.weekdayTime(date: $0) }
                ?? status?.type?.shortDetail
                ?? "Upcoming"
        case .unknown:
            headline = status?.type?.description ?? "Game"
        }
        let city = [competition?.venue?.address?.city, competition?.venue?.address?.state].compactMap { $0 }.joined(separator: ", ")
        let feedLogo = opponent?.team?.logo ?? opponent?.team?.logos?.first?.href
        return GameSnapshot(
            id: event.id.value,
            phase: phase,
            start: DateParser.parse(event.date ?? competition?.date),
            opponentName: opponentTeam?.displayName ?? opponent?.team?.displayName ?? event.name ?? "Opponent",
            opponentCode: opponentCode,
            opponentLogoURL: opponentTeam?.logoURL ?? feedLogo.flatMap(URL.init(string:)),
            isHome: isHome,
            venue: competition?.venue?.fullName,
            venueCity: city.isEmpty ? nil : city,
            broadcasts: broadcasts,
            homeScore: phase == .upcoming ? nil : Int(home?.score?.value ?? ""),
            awayScore: phase == .upcoming ? nil : Int(away?.score?.value ?? ""),
            homeCode: home?.team?.abbreviation ?? "",
            awayCode: away?.team?.abbreviation ?? "",
            periodLabel: period,
            clock: clock,
            detailHeadline: headline,
            notes: [competition?.situation?.possessionText].compactMap { $0 }
        )
    }

    /// Q1–Q4, then OT / 2OT.
    static func periodLabel(_ number: Int) -> String? {
        guard number > 0 else { return nil }
        return number <= 4 ? "Q\(number)" : (number == 5 ? "OT" : "\(number - 4)OT")
    }

    /// The summary header is fresher than the team schedule for live state and scores.
    static func merge(game: GameSnapshot?, summary: ESPNSummaryResponse, team: TeamSummary, catalog: TeamCatalog = .shared) -> GameSnapshot? {
        let fromHeader = summary.header.map { gameSnapshot(event: $0, team: team, catalog: catalog) }
        guard var game = game ?? fromHeader else { return nil }
        if let fresh = fromHeader, fresh.id == game.id, fresh.phase != .unknown {
            game.phase = fresh.phase
            game.homeScore = fresh.homeScore ?? game.homeScore
            game.awayScore = fresh.awayScore ?? game.awayScore
            game.periodLabel = fresh.periodLabel
            game.clock = fresh.clock
            game.detailHeadline = fresh.detailHeadline
            if !fresh.notes.isEmpty { game.notes = fresh.notes }
        }
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

    private static func rosterAthletes(_ roster: ESPNRosterResponse?) -> [String: ESPNRosterAthlete] {
        var map: [String: ESPNRosterAthlete] = [:]
        for group in roster?.athletes ?? [] {
            for athlete in group.items ?? [] {
                if let id = athlete.id?.value {
                    map[id] = athlete
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
    static func leaders(_ teamID: String, season: Int) -> URL {
        URL(string: "https://sports.core.api.espn.com/v2/sports/football/leagues/nfl/seasons/\(season)/types/2/teams/\(teamID)/leaders")!
    }
    static let standings = URL(string: "https://site.api.espn.com/apis/v2/sports/football/nfl/standings?level=3")!
}
