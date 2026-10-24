import Foundation

struct NHLStandingsResponse: Decodable {
    var standingsDateTimeUtc: String?
    var standings: [NHLStandingRow]
}

struct NHLStandingRow: Decodable {
    var conferenceName: String?
    var conferenceSequence: Int?
    var divisionName: String?
    var divisionSequence: Int?
    var leagueSequence: Int?
    var gamesPlayed: Int?
    var wins: Int?
    var losses: Int?
    var otLosses: Int?
    var points: Int?
    var goalFor: Int?
    var goalAgainst: Int?
    var streakCode: String?
    var streakCount: Int?
    var teamAbbrev: FlexibleText
    var teamName: FlexibleText
    var teamLogo: String?
}

struct NHLClubStatsResponse: Decodable {
    var season: FlexibleID?
    var gameType: FlexibleID?
    var skaters: [NHLSkater]
    var goalies: [NHLGoalie]
}

struct NHLSkater: Decodable {
    var playerId: Int
    var firstName: FlexibleText
    var lastName: FlexibleText
    var positionCode: String?
    var headshot: String?
    var gamesPlayed: Int?
    var goals: Int?
    var assists: Int?
    var points: Int?
    var plusMinus: Int?
    var avgTimeOnIcePerGame: Double?
}

struct NHLGoalie: Decodable {
    var playerId: Int
    var firstName: FlexibleText
    var lastName: FlexibleText
    var headshot: String?
    var gamesPlayed: Int?
    var wins: Int?
    var losses: Int?
    var overtimeLosses: Int?
    var goalsAgainstAverage: Double?
    var savePercentage: Double?
}

struct NHLWeekScheduleResponse: Decodable {
    var games: [NHLScheduleGame]
}

struct NHLScheduleGame: Decodable {
    var id: Int
    var season: Int?
    var gameType: Int?
    var gameDate: String?
    var startTimeUTC: String?
    var venue: FlexibleText?
    var venueTimezone: String?
    var gameState: String?
    var tvBroadcasts: [NHLBroadcast]?
    var awayTeam: NHLGameTeam
    var homeTeam: NHLGameTeam
    var periodDescriptor: NHLPeriod?
    var clock: NHLClock?
}

struct NHLBroadcast: Decodable {
    var network: String?
    var market: String?
    var countryCode: String?
}

struct NHLGameTeam: Decodable {
    var id: Int?
    var abbrev: String
    var commonName: FlexibleText?
    var placeName: FlexibleText?
    var logo: String?
    var score: Int?
    var sog: Int?
}

struct NHLPeriod: Decodable {
    var number: Int?
    var periodType: String?
}

struct NHLClock: Decodable {
    var timeRemaining: String?
    var inIntermission: Bool?
    var running: Bool?
}

struct NHLLandingResponse: Decodable {
    var id: Int?
    var startTimeUTC: String?
    var venue: FlexibleText?
    var venueLocation: FlexibleText?
    var tvBroadcasts: [NHLBroadcast]?
    var gameState: String?
    var awayTeam: NHLGameTeam
    var homeTeam: NHLGameTeam
    var periodDescriptor: NHLPeriod?
    var clock: NHLClock?
    var summary: NHLLandingSummary?
    var matchup: NHLMatchup?
}

struct NHLLandingSummary: Decodable {
    var scoring: [NHLScoringPeriod]?
    var threeStars: [NHLStar]?
}

struct NHLScoringPeriod: Decodable {
    var periodDescriptor: NHLPeriod?
    var goals: [NHLGoal]
}

struct NHLGoal: Decodable {
    var name: FlexibleText?
    var teamAbbrev: FlexibleText?
    var strength: String?
}

struct NHLStar: Decodable {
    var name: FlexibleText?
}

struct NHLMatchup: Decodable {
    var skaterComparison: NHLComparison?
}

struct NHLComparison: Decodable {
    var contextLabel: String?
    var leaders: [NHLComparisonLeader]?
}

struct NHLComparisonLeader: Decodable {
    var category: String?
    var awayLeader: NHLComparisonPlayer?
    var homeLeader: NHLComparisonPlayer?
}

struct NHLComparisonPlayer: Decodable {
    var playerId: Int?
    var firstName: FlexibleText?
    var lastName: FlexibleText?
    var positionCode: String?
    var value: Double?
}

struct NHLBoxscoreResponse: Decodable {
    var playerByGameStats: NHLPlayerByGameStats?
    var gameOutcome: NHLGameOutcome?
}

struct NHLPlayerByGameStats: Decodable {
    var awayTeam: NHLBoxTeam?
    var homeTeam: NHLBoxTeam?
}

struct NHLBoxTeam: Decodable {
    var forwards: [NHLBoxSkater]?
    var defense: [NHLBoxSkater]?
    var goalies: [NHLBoxGoalie]?
}

struct NHLBoxSkater: Decodable {
    var playerId: Int
    var name: FlexibleText
    var position: String?
    var goals: Int?
    var assists: Int?
    var points: Int?
    var toi: String?
}

struct NHLBoxGoalie: Decodable {
    var playerId: Int
    var name: FlexibleText
    var saveShotsAgainst: String?
    var goalsAgainst: Int?
    var starter: Bool?
}

struct NHLGameOutcome: Decodable {
    var lastPeriodType: String?
}

struct NHLTeamSummaryResponse: Decodable {
    var data: [NHLTeamSummaryRow]
}

struct NHLTeamSummaryRow: Decodable {
    var teamFullName: String?
    var teamId: Int?
    var gamesPlayed: Int?
    var wins: Int?
    var losses: Int?
    var otLosses: Int?
    var points: Int?
    var goalsForPerGame: Double?
    var goalsAgainstPerGame: Double?
    var powerPlayPct: Double?
    var penaltyKillPct: Double?
    var faceoffWinPct: Double?
    var shotsForPerGame: Double?
}
