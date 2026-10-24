import Foundation

public enum GamePhase: String, Hashable, Codable, Sendable {
    case upcoming
    case live
    case final
    case unknown
}

public struct StatLine: Hashable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var value: String
    public var detail: String?

    public init(id: String? = nil, label: String, value: String, detail: String? = nil) {
        self.id = id ?? label
        self.label = label
        self.value = value
        self.detail = detail
    }
}

public struct StandingRow: Hashable, Sendable, Identifiable {
    public var id: String
    public var team: TeamSummary
    public var rank: Int
    public var gamesPlayed: Int
    public var record: String
    public var pointsOrPct: String
    public var pointsFor: String
    public var pointsAgainst: String
    public var streak: String?
    public var isFavourite: Bool

    public init(
        team: TeamSummary,
        rank: Int,
        gamesPlayed: Int,
        record: String,
        pointsOrPct: String,
        pointsFor: String,
        pointsAgainst: String,
        streak: String? = nil,
        isFavourite: Bool = false
    ) {
        self.id = team.id.description
        self.team = team
        self.rank = rank
        self.gamesPlayed = gamesPlayed
        self.record = record
        self.pointsOrPct = pointsOrPct
        self.pointsFor = pointsFor
        self.pointsAgainst = pointsAgainst
        self.streak = streak
        self.isFavourite = isFavourite
    }
}

public struct StandingsSnapshot: Hashable, Sendable {
    public var league: League
    public var asOf: Date?
    public var leagueRows: [StandingRow]
    public var conferenceRows: [StandingRow]
    public var divisionRows: [StandingRow]
    public var conferenceName: String?
    public var divisionName: String?

    public init(
        league: League,
        asOf: Date? = nil,
        leagueRows: [StandingRow],
        conferenceRows: [StandingRow],
        divisionRows: [StandingRow],
        conferenceName: String? = nil,
        divisionName: String? = nil
    ) {
        self.league = league
        self.asOf = asOf
        self.leagueRows = leagueRows
        self.conferenceRows = conferenceRows
        self.divisionRows = divisionRows
        self.conferenceName = conferenceName
        self.divisionName = divisionName
    }
}

public struct PlayerStat: Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var position: String?
    public var headshotURL: URL?
    public var line: String
    public var secondary: String?

    public init(id: String, name: String, position: String? = nil, headshotURL: URL? = nil, line: String, secondary: String? = nil) {
        self.id = id
        self.name = name
        self.position = position
        self.headshotURL = headshotURL
        self.line = line
        self.secondary = secondary
    }
}

public struct TeamStatBlock: Hashable, Sendable {
    public var headline: String
    public var items: [StatLine]
    public var players: [PlayerStat]

    public init(headline: String, items: [StatLine], players: [PlayerStat] = []) {
        self.headline = headline
        self.items = items
        self.players = players
    }
}

public struct BroadcastInfo: Hashable, Sendable, Identifiable {
    public var id: String { network }
    public var network: String
    public var market: String?

    public init(network: String, market: String? = nil) {
        self.network = network
        self.market = market
    }
}

public struct GameSnapshot: Hashable, Sendable, Identifiable {
    public var id: String
    public var phase: GamePhase
    public var start: Date?
    public var opponentName: String
    public var opponentCode: String
    public var opponentLogoURL: URL?
    public var isHome: Bool
    public var venue: String?
    public var venueCity: String?
    public var broadcasts: [BroadcastInfo]
    public var homeScore: Int?
    public var awayScore: Int?
    public var homeCode: String
    public var awayCode: String
    public var periodLabel: String?
    public var clock: String?
    public var detailHeadline: String
    public var notes: [String]
    public var scoringSummary: [String]
    public var boxscorePlayers: [PlayerStat]

    public init(
        id: String,
        phase: GamePhase,
        start: Date? = nil,
        opponentName: String,
        opponentCode: String,
        opponentLogoURL: URL? = nil,
        isHome: Bool,
        venue: String? = nil,
        venueCity: String? = nil,
        broadcasts: [BroadcastInfo] = [],
        homeScore: Int? = nil,
        awayScore: Int? = nil,
        homeCode: String,
        awayCode: String,
        periodLabel: String? = nil,
        clock: String? = nil,
        detailHeadline: String,
        notes: [String] = [],
        scoringSummary: [String] = [],
        boxscorePlayers: [PlayerStat] = []
    ) {
        self.id = id
        self.phase = phase
        self.start = start
        self.opponentName = opponentName
        self.opponentCode = opponentCode
        self.opponentLogoURL = opponentLogoURL
        self.isHome = isHome
        self.venue = venue
        self.venueCity = venueCity
        self.broadcasts = broadcasts
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.homeCode = homeCode
        self.awayCode = awayCode
        self.periodLabel = periodLabel
        self.clock = clock
        self.detailHeadline = detailHeadline
        self.notes = notes
        self.scoringSummary = scoringSummary
        self.boxscorePlayers = boxscorePlayers
    }

    public var scoreLine: String? {
        guard let homeScore, let awayScore else { return nil }
        return "\(awayCode) \(awayScore)  @  \(homeCode) \(homeScore)"
    }

    public var teamScore: Int? { isHome ? homeScore : awayScore }
    public var opponentScore: Int? { isHome ? awayScore : homeScore }

    /// "W", "L" or "T" for finished games with scores.
    public var outcome: String? {
        guard phase == .final, let teamScore, let opponentScore else { return nil }
        return teamScore > opponentScore ? "W" : (teamScore < opponentScore ? "L" : "T")
    }
}

public struct LinePlayer: Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var position: String?

    public init(id: String? = nil, name: String, position: String? = nil) {
        self.id = id ?? "\(position ?? "")-\(name)"
        self.name = name
        self.position = position
    }
}

public struct LineUnit: Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var players: [LinePlayer]

    public init(id: String, title: String, players: [LinePlayer]) {
        self.id = id
        self.title = title
        self.players = players
    }
}

public struct LineCombinationReport: Hashable, Sendable {
    public var sourceName: String
    public var updatedAt: Date?
    public var sourceNote: String?
    public var forwardLines: [LineUnit]
    public var defensePairs: [LineUnit]
    public var goalies: [LineUnit]
    public var isUnavailable: Bool
    public var unavailableReason: String?

    public init(
        sourceName: String,
        updatedAt: Date? = nil,
        sourceNote: String? = nil,
        forwardLines: [LineUnit] = [],
        defensePairs: [LineUnit] = [],
        goalies: [LineUnit] = [],
        isUnavailable: Bool = false,
        unavailableReason: String? = nil
    ) {
        self.sourceName = sourceName
        self.updatedAt = updatedAt
        self.sourceNote = sourceNote
        self.forwardLines = forwardLines
        self.defensePairs = defensePairs
        self.goalies = goalies
        self.isUnavailable = isUnavailable
        self.unavailableReason = unavailableReason
    }

    public static func unavailable(sourceName: String, reason: String) -> LineCombinationReport {
        LineCombinationReport(sourceName: sourceName, isUnavailable: true, unavailableReason: reason)
    }
}

public struct DepthSlot: Hashable, Sendable, Identifiable {
    public var id: String
    public var position: String
    public var playerName: String
    public var unitName: String

    public init(id: String? = nil, position: String, playerName: String, unitName: String) {
        self.id = id ?? "\(unitName)-\(position)-\(playerName)"
        self.position = position
        self.playerName = playerName
        self.unitName = unitName
    }
}

public struct DepthChartReport: Hashable, Sendable {
    public var sourceName: String
    public var starters: [DepthSlot]
    public var units: [String: [DepthSlot]]
    /// Unit names in feed order (dictionaries lose it).
    public var unitOrder: [String]
    public var isUnavailable: Bool
    public var unavailableReason: String?

    public init(
        sourceName: String,
        starters: [DepthSlot] = [],
        units: [String: [DepthSlot]] = [:],
        unitOrder: [String]? = nil,
        isUnavailable: Bool = false,
        unavailableReason: String? = nil
    ) {
        self.sourceName = sourceName
        self.starters = starters
        self.units = units
        self.unitOrder = unitOrder ?? units.keys.sorted()
        self.isUnavailable = isUnavailable
        self.unavailableReason = unavailableReason
    }
}

public struct InjuryItem: Hashable, Sendable, Identifiable {
    public var id: String
    public var playerName: String
    public var position: String?
    public var injury: String?
    public var status: String
    public var comment: String?
    public var date: Date?
    public var isKey: Bool

    public init(
        id: String,
        playerName: String,
        position: String? = nil,
        injury: String? = nil,
        status: String,
        comment: String? = nil,
        date: Date? = nil,
        isKey: Bool
    ) {
        self.id = id
        self.playerName = playerName
        self.position = position
        self.injury = injury
        self.status = status
        self.comment = comment
        self.date = date
        self.isKey = isKey
    }
}

public struct InjuryReport: Hashable, Sendable {
    public var sourceName: String
    public var items: [InjuryItem]
    public var isUnavailable: Bool
    public var unavailableReason: String?

    public init(
        sourceName: String,
        items: [InjuryItem] = [],
        isUnavailable: Bool = false,
        unavailableReason: String? = nil
    ) {
        self.sourceName = sourceName
        self.items = items
        self.isUnavailable = isUnavailable
        self.unavailableReason = unavailableReason
    }

    public var keyItems: [InjuryItem] { items.filter(\.isKey) }

    public static func unavailable(sourceName: String, reason: String) -> InjuryReport {
        InjuryReport(sourceName: sourceName, isUnavailable: true, unavailableReason: reason)
    }
}

public struct TeamDashboard: Hashable, Sendable, Identifiable {
    public var team: TeamSummary
    public var standings: StandingsSnapshot
    public var teamStats: TeamStatBlock
    public var game: GameSnapshot?
    public var lines: LineCombinationReport?
    public var depthChart: DepthChartReport?
    public var injuries: InjuryReport?
    public var fetchedAt: Date

    public var id: String { team.id.description }

    public init(
        team: TeamSummary,
        standings: StandingsSnapshot,
        teamStats: TeamStatBlock,
        game: GameSnapshot? = nil,
        lines: LineCombinationReport? = nil,
        depthChart: DepthChartReport? = nil,
        injuries: InjuryReport? = nil,
        fetchedAt: Date = Date()
    ) {
        self.team = team
        self.standings = standings
        self.teamStats = teamStats
        self.game = game
        self.lines = lines
        self.depthChart = depthChart
        self.injuries = injuries
        self.fetchedAt = fetchedAt
    }
}

public enum SportsDeskError: Error, Equatable, Sendable {
    case unknownTeam(TeamID)
    case unsupportedLeague(League)
    case network(String)
    case decoding(String)
    case unavailable(String)
}

extension SportsDeskError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unknownTeam(let id): return "\(id.code) isn't a known \(id.league.displayName) team."
        case .unsupportedLeague(let league): return "\(league.displayName) isn't supported yet."
        case .network(let detail): return "The data feed didn't respond (\(detail))."
        case .decoding(let detail): return "The data feed changed shape (\(detail))."
        case .unavailable(let detail): return detail
        }
    }
}
