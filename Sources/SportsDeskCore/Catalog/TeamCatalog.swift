import Foundation

public struct TeamCatalog: Sendable {
    public static let shared = TeamCatalog()

    public let teams: [TeamSummary]

    public init(teams: [TeamSummary] = TeamCatalog.allTeams) {
        self.teams = teams
    }

    public func team(for id: TeamID) -> TeamSummary? {
        teams.first { $0.id == id || ($0.id.league == id.league && $0.abbreviation == id.code) }
    }

    public func teams(in league: League) -> [TeamSummary] {
        teams.filter { $0.id.league == league }.sorted { $0.displayName < $1.displayName }
    }

    public func required(_ id: TeamID) throws -> TeamSummary {
        guard let team = team(for: id) else { throw SportsDeskError.unknownTeam(id) }
        return team
    }

    public static let allTeams: [TeamSummary] = nhl + nfl

    private static func nhlTeam(
        _ abbrev: String,
        city: String,
        name: String,
        conference: String,
        division: String,
        primary: String,
        secondary: String,
        nhlID: String
    ) -> TeamSummary {
        TeamSummary(
            id: TeamID(league: .nhl, code: abbrev),
            displayName: "\(city) \(name)",
            shortName: name,
            city: city,
            abbreviation: abbrev,
            conference: conference,
            division: division,
            primaryHex: primary,
            secondaryHex: secondary,
            logoURL: URL(string: "https://assets.nhle.com/logos/nhl/svg/\(abbrev)_light.svg"),
            providerCode: abbrev
        )
    }

    private static func nflTeam(
        _ abbrev: String,
        espnID: String,
        city: String,
        name: String,
        conference: String,
        division: String,
        primary: String,
        secondary: String
    ) -> TeamSummary {
        TeamSummary(
            id: TeamID(league: .nfl, code: abbrev),
            displayName: "\(city) \(name)",
            shortName: name,
            city: city,
            abbreviation: abbrev,
            conference: conference,
            division: division,
            primaryHex: primary,
            secondaryHex: secondary,
            logoURL: URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(abbrev.lowercased()).png"),
            providerCode: espnID
        )
    }

    public static let nhl: [TeamSummary] = [
        nhlTeam("ANA", city: "Anaheim", name: "Ducks", conference: "Western", division: "Pacific", primary: "FC4C02", secondary: "B5985A", nhlID: "24"),
        nhlTeam("BOS", city: "Boston", name: "Bruins", conference: "Eastern", division: "Atlantic", primary: "FFB81C", secondary: "000000", nhlID: "6"),
        nhlTeam("BUF", city: "Buffalo", name: "Sabres", conference: "Eastern", division: "Atlantic", primary: "003087", secondary: "FFB81C", nhlID: "7"),
        nhlTeam("CAR", city: "Carolina", name: "Hurricanes", conference: "Eastern", division: "Metropolitan", primary: "CE1126", secondary: "000000", nhlID: "12"),
        nhlTeam("CBJ", city: "Columbus", name: "Blue Jackets", conference: "Eastern", division: "Metropolitan", primary: "002654", secondary: "CE1126", nhlID: "29"),
        nhlTeam("CGY", city: "Calgary", name: "Flames", conference: "Western", division: "Pacific", primary: "D2001C", secondary: "FAAF19", nhlID: "20"),
        nhlTeam("CHI", city: "Chicago", name: "Blackhawks", conference: "Western", division: "Central", primary: "CF0A2C", secondary: "000000", nhlID: "16"),
        nhlTeam("COL", city: "Colorado", name: "Avalanche", conference: "Western", division: "Central", primary: "6F263D", secondary: "236192", nhlID: "21"),
        nhlTeam("DAL", city: "Dallas", name: "Stars", conference: "Western", division: "Central", primary: "006847", secondary: "8F8F8C", nhlID: "25"),
        nhlTeam("DET", city: "Detroit", name: "Red Wings", conference: "Eastern", division: "Atlantic", primary: "CE1126", secondary: "FFFFFF", nhlID: "17"),
        nhlTeam("EDM", city: "Edmonton", name: "Oilers", conference: "Western", division: "Pacific", primary: "041E42", secondary: "FF4C00", nhlID: "22"),
        nhlTeam("FLA", city: "Florida", name: "Panthers", conference: "Eastern", division: "Atlantic", primary: "041E42", secondary: "C8102E", nhlID: "13"),
        nhlTeam("LAK", city: "Los Angeles", name: "Kings", conference: "Western", division: "Pacific", primary: "111111", secondary: "A2AAAD", nhlID: "26"),
        nhlTeam("MIN", city: "Minnesota", name: "Wild", conference: "Western", division: "Central", primary: "154734", secondary: "A6192E", nhlID: "30"),
        nhlTeam("MTL", city: "Montréal", name: "Canadiens", conference: "Eastern", division: "Atlantic", primary: "AF1E2D", secondary: "192168", nhlID: "8"),
        nhlTeam("NJD", city: "New Jersey", name: "Devils", conference: "Eastern", division: "Metropolitan", primary: "CE1126", secondary: "000000", nhlID: "1"),
        nhlTeam("NSH", city: "Nashville", name: "Predators", conference: "Western", division: "Central", primary: "FFB81C", secondary: "041E42", nhlID: "18"),
        nhlTeam("NYI", city: "New York", name: "Islanders", conference: "Eastern", division: "Metropolitan", primary: "00539B", secondary: "F47D30", nhlID: "2"),
        nhlTeam("NYR", city: "New York", name: "Rangers", conference: "Eastern", division: "Metropolitan", primary: "0038A8", secondary: "CE1126", nhlID: "3"),
        nhlTeam("OTT", city: "Ottawa", name: "Senators", conference: "Eastern", division: "Atlantic", primary: "C52032", secondary: "C2912C", nhlID: "9"),
        nhlTeam("PHI", city: "Philadelphia", name: "Flyers", conference: "Eastern", division: "Metropolitan", primary: "F74902", secondary: "000000", nhlID: "4"),
        nhlTeam("PIT", city: "Pittsburgh", name: "Penguins", conference: "Eastern", division: "Metropolitan", primary: "FCB514", secondary: "000000", nhlID: "5"),
        nhlTeam("SEA", city: "Seattle", name: "Kraken", conference: "Western", division: "Pacific", primary: "001628", secondary: "99D9D9", nhlID: "55"),
        nhlTeam("SJS", city: "San Jose", name: "Sharks", conference: "Western", division: "Pacific", primary: "006D75", secondary: "EA7200", nhlID: "28"),
        nhlTeam("STL", city: "St. Louis", name: "Blues", conference: "Western", division: "Central", primary: "002F87", secondary: "FCB514", nhlID: "19"),
        nhlTeam("TBL", city: "Tampa Bay", name: "Lightning", conference: "Eastern", division: "Atlantic", primary: "002868", secondary: "FFFFFF", nhlID: "14"),
        nhlTeam("TOR", city: "Toronto", name: "Maple Leafs", conference: "Eastern", division: "Atlantic", primary: "00205B", secondary: "FFFFFF", nhlID: "10"),
        nhlTeam("UTA", city: "Utah", name: "Mammoth", conference: "Western", division: "Central", primary: "6CACE4", secondary: "010101", nhlID: "68"),
        nhlTeam("VAN", city: "Vancouver", name: "Canucks", conference: "Western", division: "Pacific", primary: "00205B", secondary: "00843D", nhlID: "23"),
        nhlTeam("VGK", city: "Vegas", name: "Golden Knights", conference: "Western", division: "Pacific", primary: "B4975A", secondary: "333F42", nhlID: "54"),
        nhlTeam("WPG", city: "Winnipeg", name: "Jets", conference: "Western", division: "Central", primary: "041E42", secondary: "004C97", nhlID: "52"),
        nhlTeam("WSH", city: "Washington", name: "Capitals", conference: "Eastern", division: "Metropolitan", primary: "C8102E", secondary: "041E42", nhlID: "15")
    ]

    public static let nfl: [TeamSummary] = [
        nflTeam("ARI", espnID: "22", city: "Arizona", name: "Cardinals", conference: "NFC", division: "NFC West", primary: "97233F", secondary: "000000"),
        nflTeam("ATL", espnID: "1", city: "Atlanta", name: "Falcons", conference: "NFC", division: "NFC South", primary: "A71930", secondary: "000000"),
        nflTeam("BAL", espnID: "33", city: "Baltimore", name: "Ravens", conference: "AFC", division: "AFC North", primary: "241773", secondary: "000000"),
        nflTeam("BUF", espnID: "2", city: "Buffalo", name: "Bills", conference: "AFC", division: "AFC East", primary: "00338D", secondary: "C60C30"),
        nflTeam("CAR", espnID: "29", city: "Carolina", name: "Panthers", conference: "NFC", division: "NFC South", primary: "0085CA", secondary: "101820"),
        nflTeam("CHI", espnID: "3", city: "Chicago", name: "Bears", conference: "NFC", division: "NFC North", primary: "0B162A", secondary: "C83803"),
        nflTeam("CIN", espnID: "4", city: "Cincinnati", name: "Bengals", conference: "AFC", division: "AFC North", primary: "FB4F14", secondary: "000000"),
        nflTeam("CLE", espnID: "5", city: "Cleveland", name: "Browns", conference: "AFC", division: "AFC North", primary: "311D00", secondary: "FF3C00"),
        nflTeam("DAL", espnID: "6", city: "Dallas", name: "Cowboys", conference: "NFC", division: "NFC East", primary: "003594", secondary: "869397"),
        nflTeam("DEN", espnID: "7", city: "Denver", name: "Broncos", conference: "AFC", division: "AFC West", primary: "FB4F14", secondary: "002244"),
        nflTeam("DET", espnID: "8", city: "Detroit", name: "Lions", conference: "NFC", division: "NFC North", primary: "0076B6", secondary: "B0B7BC"),
        nflTeam("GB", espnID: "9", city: "Green Bay", name: "Packers", conference: "NFC", division: "NFC North", primary: "203731", secondary: "FFB612"),
        nflTeam("HOU", espnID: "34", city: "Houston", name: "Texans", conference: "AFC", division: "AFC South", primary: "03202F", secondary: "A71930"),
        nflTeam("IND", espnID: "11", city: "Indianapolis", name: "Colts", conference: "AFC", division: "AFC South", primary: "002C5F", secondary: "A2AAAD"),
        nflTeam("JAX", espnID: "30", city: "Jacksonville", name: "Jaguars", conference: "AFC", division: "AFC South", primary: "006778", secondary: "D7A22A"),
        nflTeam("KC", espnID: "12", city: "Kansas City", name: "Chiefs", conference: "AFC", division: "AFC West", primary: "E31837", secondary: "FFB81C"),
        nflTeam("LAC", espnID: "24", city: "Los Angeles", name: "Chargers", conference: "AFC", division: "AFC West", primary: "0080C6", secondary: "FFC20E"),
        nflTeam("LAR", espnID: "14", city: "Los Angeles", name: "Rams", conference: "NFC", division: "NFC West", primary: "003594", secondary: "FFA300"),
        nflTeam("LV", espnID: "13", city: "Las Vegas", name: "Raiders", conference: "AFC", division: "AFC West", primary: "000000", secondary: "A5ACAF"),
        nflTeam("MIA", espnID: "15", city: "Miami", name: "Dolphins", conference: "AFC", division: "AFC East", primary: "008E97", secondary: "FC4C02"),
        nflTeam("MIN", espnID: "16", city: "Minnesota", name: "Vikings", conference: "NFC", division: "NFC North", primary: "4F2683", secondary: "FFC62F"),
        nflTeam("NE", espnID: "17", city: "New England", name: "Patriots", conference: "AFC", division: "AFC East", primary: "002244", secondary: "C60C30"),
        nflTeam("NO", espnID: "18", city: "New Orleans", name: "Saints", conference: "NFC", division: "NFC South", primary: "D3BC8D", secondary: "101820"),
        nflTeam("NYG", espnID: "19", city: "New York", name: "Giants", conference: "NFC", division: "NFC East", primary: "0B2265", secondary: "A71930"),
        nflTeam("NYJ", espnID: "20", city: "New York", name: "Jets", conference: "AFC", division: "AFC East", primary: "125740", secondary: "000000"),
        nflTeam("PHI", espnID: "21", city: "Philadelphia", name: "Eagles", conference: "NFC", division: "NFC East", primary: "004C54", secondary: "A5ACAF"),
        nflTeam("PIT", espnID: "23", city: "Pittsburgh", name: "Steelers", conference: "AFC", division: "AFC North", primary: "FFB612", secondary: "101820"),
        nflTeam("SEA", espnID: "26", city: "Seattle", name: "Seahawks", conference: "NFC", division: "NFC West", primary: "002244", secondary: "69BE28"),
        nflTeam("SF", espnID: "25", city: "San Francisco", name: "49ers", conference: "NFC", division: "NFC West", primary: "AA0000", secondary: "B3995D"),
        nflTeam("TB", espnID: "27", city: "Tampa Bay", name: "Buccaneers", conference: "NFC", division: "NFC South", primary: "D50A0A", secondary: "34302B"),
        nflTeam("TEN", espnID: "10", city: "Tennessee", name: "Titans", conference: "AFC", division: "AFC South", primary: "0C2340", secondary: "4B92DB"),
        nflTeam("WSH", espnID: "28", city: "Washington", name: "Commanders", conference: "NFC", division: "NFC East", primary: "5A1414", secondary: "FFB612")
    ]

    public static let dailyFaceoffSlugs: [String: String] = [
        "ANA": "anaheim-ducks",
        "BOS": "boston-bruins",
        "BUF": "buffalo-sabres",
        "CAR": "carolina-hurricanes",
        "CBJ": "columbus-blue-jackets",
        "CGY": "calgary-flames",
        "CHI": "chicago-blackhawks",
        "COL": "colorado-avalanche",
        "DAL": "dallas-stars",
        "DET": "detroit-red-wings",
        "EDM": "edmonton-oilers",
        "FLA": "florida-panthers",
        "LAK": "los-angeles-kings",
        "MIN": "minnesota-wild",
        "MTL": "montreal-canadiens",
        "NJD": "new-jersey-devils",
        "NSH": "nashville-predators",
        "NYI": "new-york-islanders",
        "NYR": "new-york-rangers",
        "OTT": "ottawa-senators",
        "PHI": "philadelphia-flyers",
        "PIT": "pittsburgh-penguins",
        "SEA": "seattle-kraken",
        "SJS": "san-jose-sharks",
        "STL": "st-louis-blues",
        "TBL": "tampa-bay-lightning",
        "TOR": "toronto-maple-leafs",
        "UTA": "utah-mammoth",
        "VAN": "vancouver-canucks",
        "VGK": "vegas-golden-knights",
        "WPG": "winnipeg-jets",
        "WSH": "washington-capitals"
    ]
}
