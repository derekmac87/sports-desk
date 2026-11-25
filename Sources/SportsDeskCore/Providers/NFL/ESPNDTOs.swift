import Foundation

struct ESPNTeamResponse: Decodable {
    var team: ESPNTeam
}

struct ESPNTeam: Decodable {
    var id: FlexibleID
    var abbreviation: String?
    var displayName: String?
    var location: String?
    var name: String?
    var logos: [ESPNLogo]?
    var record: ESPNRecord?
    var nextEvent: [ESPNEvent]?
}

struct ESPNLogo: Decodable {
    var href: String?
}

struct ESPNRecord: Decodable {
    var items: [ESPNRecordItem]?
}

struct ESPNRecordItem: Decodable {
    var type: String?
    var summary: String?
    var stats: [ESPNNamedStat]?
}

struct ESPNNamedStat: Decodable {
    var name: String?
    var displayName: String?
    var abbreviation: String?
    var value: Double?
    var displayValue: String?
}

struct ESPNScheduleResponse: Decodable {
    var events: [ESPNEvent]?
    var season: ESPNSeason?
}

struct ESPNSeason: Decodable {
    var year: Int?
    var type: Int?
}

struct ESPNEvent: Decodable {
    var id: FlexibleID
    var date: String?
    var name: String?
    var shortName: String?
    var competitions: [ESPNCompetition]?
}

struct ESPNCompetition: Decodable {
    var id: FlexibleID?
    var date: String?
    var status: ESPNStatus?
    var venue: ESPNVenue?
    var broadcasts: [ESPNBroadcast]?
    var competitors: [ESPNCompetitor]?
    var situation: ESPNSituation?
}

struct ESPNStatus: Decodable {
    var displayClock: String?
    var period: Int?
    var type: ESPNStatusType?
}

struct ESPNStatusType: Decodable {
    var state: String?
    var completed: Bool?
    var description: String?
    var detail: String?
    var shortDetail: String?
}

struct ESPNVenue: Decodable {
    var fullName: String?
    var address: ESPNAddress?
}

struct ESPNAddress: Decodable {
    var city: String?
    var state: String?
}

struct ESPNBroadcast: Decodable {
    var names: [String]?
    var media: ESPNBroadcastMedia?
    var market: ESPNBroadcastMarket?
}

struct ESPNBroadcastMedia: Decodable {
    var shortName: String?
}

struct ESPNBroadcastMarket: Decodable {
    var type: String?
}

struct ESPNCompetitor: Decodable {
    var homeAway: String?
    var score: FlexibleID?
    var team: ESPNCompetitorTeam?
}

struct ESPNCompetitorTeam: Decodable {
    var id: FlexibleID?
    var abbreviation: String?
    var displayName: String?
    var logo: String?
    var logos: [ESPNLogo]?
}

struct ESPNSituation: Decodable {
    var downDistanceText: String?
    var possessionText: String?
    var shortDownDistanceText: String?
}

struct ESPNStandingsResponse: Decodable {
    var children: [ESPNStandingsGroup]?
}

struct ESPNStandingsGroup: Decodable {
    var abbreviation: String?
    var name: String?
    var isConference: Bool?
    var children: [ESPNStandingsGroup]?
    var standings: ESPNStandingsTable?
}

struct ESPNStandingsTable: Decodable {
    var entries: [ESPNStandingEntry]?
}

struct ESPNStandingEntry: Decodable {
    var team: ESPNStandingTeam
    var stats: [ESPNNamedStat]?
}

struct ESPNStandingTeam: Decodable {
    var id: FlexibleID
    var abbreviation: String?
    var displayName: String?
    var location: String?
    var name: String?
}

struct ESPNStatisticsResponse: Decodable {
    var results: ESPNStatisticsResults?
    var team: ESPNStatisticsTeam?
}

struct ESPNStatisticsResults: Decodable {
    var stats: ESPNStatisticsBlock?
}

struct ESPNStatisticsBlock: Decodable {
    var categories: [ESPNStatCategory]?
}

struct ESPNStatCategory: Decodable {
    var name: String?
    var displayName: String?
    var stats: [ESPNNamedStat]?
}

struct ESPNStatisticsTeam: Decodable {
    var recordSummary: String?
    var standingSummary: String?
}

struct ESPNDepthChartResponse: Decodable {
    var depthchart: [ESPNDepthUnit]?
}

struct ESPNDepthUnit: Decodable {
    var id: FlexibleID?
    var name: String?
    var positions: [String: ESPNDepthPosition]?
}

struct ESPNDepthPosition: Decodable {
    var position: ESPNPosition?
    var athletes: [ESPNDepthAthlete]?
}

struct ESPNPosition: Decodable {
    var abbreviation: String?
    var displayName: String?
    var name: String?
}

struct ESPNDepthAthlete: Decodable {
    var id: FlexibleID?
    var displayName: String?
}

struct ESPNRosterResponse: Decodable {
    var athletes: [ESPNRosterGroup]?
}

struct ESPNRosterGroup: Decodable {
    var name: String?
    var items: [ESPNRosterAthlete]?
}

struct ESPNRosterAthlete: Decodable {
    var id: FlexibleID?
    var displayName: String?
    var jersey: String?
    var headshot: ESPNLogo?
    var position: ESPNPosition?
    var injuries: [ESPNRosterInjury]?
}

struct ESPNRosterInjury: Decodable {
    var status: String?
    var date: String?
}

struct ESPNLeadersResponse: Decodable {
    var categories: [ESPNLeaderCategory]?
}

struct ESPNLeaderCategory: Decodable {
    var name: String?
    var displayName: String?
    var leaders: [ESPNLeader]?
}

struct ESPNLeader: Decodable {
    var displayValue: String?
    var athlete: ESPNRef?
}

struct ESPNRef: Decodable {
    var ref: String?

    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
    }
}

struct ESPNInjuriesResponse: Decodable {
    var injuries: [ESPNTeamInjuries]
}

struct ESPNTeamInjuries: Decodable {
    var id: FlexibleID
    var displayName: String?
    var injuries: [ESPNInjury]
}

struct ESPNInjury: Decodable {
    var id: FlexibleID?
    var status: String?
    var date: String?
    var shortComment: String?
    var longComment: String?
    var type: ESPNInjuryType?
    var details: ESPNInjuryDetails?
    var athlete: ESPNInjuryAthlete?
}

struct ESPNInjuryType: Decodable {
    var description: String?
    var abbreviation: String?
}

struct ESPNInjuryDetails: Decodable {
    var type: String?
    var location: String?
    var detail: String?
}

struct ESPNInjuryAthlete: Decodable {
    var displayName: String?
    var firstName: String?
    var lastName: String?
    var position: ESPNPosition?
}

struct ESPNSummaryResponse: Decodable {
    var header: ESPNEvent?
    var gameInfo: ESPNGameInfo?
    var broadcasts: [ESPNBroadcast]?
    var boxscore: ESPNBoxscore?
}

struct ESPNGameInfo: Decodable {
    var venue: ESPNVenue?
}

struct ESPNBoxscore: Decodable {
    var teams: [ESPNBoxTeam]?
}

struct ESPNBoxTeam: Decodable {
    var team: ESPNCompetitorTeam?
    var statistics: [ESPNNamedStat]?
}
