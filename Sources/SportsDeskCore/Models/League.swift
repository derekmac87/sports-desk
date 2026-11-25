import Foundation

/// Extensible league identifier. New leagues can be added without changing stored settings.
public struct League: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public static let nhl = League(rawValue: "nhl")
    public static let nfl = League(rawValue: "nfl")

    public var description: String { rawValue.uppercased() }

    public var displayName: String {
        switch self {
        case .nhl: return "NHL"
        case .nfl: return "NFL"
        default: return rawValue.uppercased()
        }
    }
}

public struct TeamID: Hashable, Codable, Sendable, CustomStringConvertible {
    public var league: League
    public var code: String

    public init(league: League, code: String) {
        self.league = league
        self.code = code.uppercased()
    }

    public var description: String { "\(league.rawValue):\(code)" }
}

public struct FavouriteTeam: Hashable, Codable, Sendable, Identifiable {
    public var league: League
    public var code: String

    public var id: String { "\(league.rawValue):\(code.uppercased())" }
    public var teamID: TeamID { TeamID(league: league, code: code) }

    public init(league: League, code: String) {
        self.league = league
        self.code = code.uppercased()
    }
}

public struct TeamSummary: Hashable, Sendable, Identifiable {
    public var id: TeamID
    public var displayName: String
    public var shortName: String
    public var city: String
    public var abbreviation: String
    public var conference: String?
    public var division: String?
    public var primaryHex: String
    public var secondaryHex: String
    public var logoURL: URL?
    public var providerCode: String

    public var league: League { id.league }

    public init(
        id: TeamID,
        displayName: String,
        shortName: String,
        city: String,
        abbreviation: String,
        conference: String? = nil,
        division: String? = nil,
        primaryHex: String,
        secondaryHex: String,
        logoURL: URL? = nil,
        providerCode: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.shortName = shortName
        self.city = city
        self.abbreviation = abbreviation
        self.conference = conference
        self.division = division
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
        self.logoURL = logoURL
        self.providerCode = providerCode ?? abbreviation.lowercased()
    }
}
