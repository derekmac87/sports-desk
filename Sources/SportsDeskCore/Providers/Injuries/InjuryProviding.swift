import Foundation

public protocol InjuryProviding: Sendable {
    var sourceName: String { get }
    func injuries(for team: TeamSummary) async -> InjuryReport
}

public struct UnavailableInjuryProvider: InjuryProviding {
    public var sourceName: String
    public var reason: String

    public init(sourceName: String = "Injuries", reason: String) {
        self.sourceName = sourceName
        self.reason = reason
    }

    public func injuries(for team: TeamSummary) async -> InjuryReport {
        .unavailable(sourceName: sourceName, reason: reason)
    }
}

/// ESPN league injury report (`site.api.espn.com/.../nfl/injuries`), filtered to one team.
/// Isolated so the source can be swapped if ESPN changes the payload.
public struct ESPNInjuryProvider: InjuryProviding {
    public var sourceName: String { "ESPN Injury Report" }
    public var client: HTTPClient
    public var endpoint: URL

    public init(
        client: HTTPClient = HTTPClient(),
        endpoint: URL = URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/injuries")!
    ) {
        self.client = client
        self.endpoint = endpoint
    }

    public func injuries(for team: TeamSummary) async -> InjuryReport {
        do {
            let response = try await client.getJSON(ESPNInjuriesResponse.self, url: endpoint)
            return Self.map(response, team: team, sourceName: sourceName)
        } catch {
            return .unavailable(
                sourceName: sourceName,
                reason: "The injury report is unavailable right now (\(error.localizedDescription))."
            )
        }
    }

    static func map(_ response: ESPNInjuriesResponse, team: TeamSummary, sourceName: String = "ESPN Injury Report") -> InjuryReport {
        let group = response.injuries.first {
            $0.id.value == team.providerCode
                || $0.id.value == team.id.code
                || ($0.displayName ?? "").localizedCaseInsensitiveCompare(team.displayName) == .orderedSame
        }
        guard let group else {
            return InjuryReport(sourceName: sourceName, items: [])
        }
        let items = group.injuries.enumerated()
            .map { index, injury in Self.item(from: injury, fallbackID: "\(team.abbreviation)-\(index)") }
            .enumerated()
            .sorted { lhs, rhs in
                let left = severity(status: lhs.element.status), right = severity(status: rhs.element.status)
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
        return InjuryReport(sourceName: sourceName, items: items)
    }

    /// Lower is more serious; used to sort the report.
    public static func severity(status: String) -> Int {
        let normalized = status.lowercased()
        if normalized.contains("reserve") || normalized == "ir" || normalized.contains("pup") || normalized.contains("nfi") { return 0 }
        if normalized.contains("out") || normalized.contains("suspend") { return 1 }
        if normalized.contains("doubt") { return 2 }
        if normalized.contains("question") { return 3 }
        if normalized.contains("probable") || normalized.contains("day") { return 4 }
        return 5
    }

    static func item(from injury: ESPNInjury, fallbackID: String) -> InjuryItem {
        let status = injury.status ?? injury.type?.description ?? "Unknown"
        let injuryType = injury.details?.type
        let name = injury.athlete?.displayName
            ?? [injury.athlete?.firstName, injury.athlete?.lastName].compactMap { $0 }.joined(separator: " ")
        return InjuryItem(
            id: injury.id?.value ?? fallbackID,
            playerName: name.isEmpty ? "Player" : name,
            position: injury.athlete?.position?.abbreviation ?? injury.athlete?.position?.displayName,
            injury: injuryType,
            status: status.capitalized,
            comment: injury.shortComment ?? injury.longComment,
            date: DateParser.parse(injury.date),
            isKey: Self.isKey(status: status)
        )
    }

    public static func isKey(status: String) -> Bool {
        let normalized = status.lowercased()
        if normalized == "active" { return false }
        let notable = ["out", "doubtful", "questionable", "injured reserve", "ir", "pup", "nfi", "suspended", "probable"]
        return notable.contains(where: { normalized.contains($0) })
    }
}
