import Foundation

public protocol LineCombinationProviding: Sendable {
    var sourceName: String { get }
    func lines(for team: TeamSummary) async -> LineCombinationReport
}

public struct UnavailableLineProvider: LineCombinationProviding {
    public var sourceName: String
    public var reason: String

    public init(sourceName: String = "Line combinations", reason: String) {
        self.sourceName = sourceName
        self.reason = reason
    }

    public func lines(for team: TeamSummary) async -> LineCombinationReport {
        .unavailable(sourceName: sourceName, reason: reason)
    }
}

/// Parses Daily Faceoff team line-combination pages (Next.js `__NEXT_DATA__`).
/// Isolated so the source can be swapped if the page layout changes or is blocked.
public struct DailyFaceoffLineProvider: LineCombinationProviding {
    public var sourceName: String { "Daily Faceoff" }
    public var client: HTTPClient
    public var slugs: [String: String]

    public init(client: HTTPClient? = nil, slugs: [String: String] = TeamCatalog.dailyFaceoffSlugs) {
        self.client = client ?? HTTPClient(
            userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        )
        self.slugs = slugs
    }

    public func lines(for team: TeamSummary) async -> LineCombinationReport {
        guard let slug = slugs[team.abbreviation],
              let url = URL(string: "https://www.dailyfaceoff.com/teams/\(slug)/line-combinations/") else {
            return .unavailable(sourceName: sourceName, reason: "No Daily Faceoff page is mapped for \(team.abbreviation).")
        }
        do {
            let data = try await client.get(url: url)
            return try Self.parse(data: data, sourceName: sourceName)
        } catch {
            return .unavailable(
                sourceName: sourceName,
                reason: "Line combinations are unavailable right now (\(error.localizedDescription))."
            )
        }
    }

    public static func parse(data: Data, sourceName: String = "Daily Faceoff") throws -> LineCombinationReport {
        guard let html = String(data: data, encoding: .utf8) else {
            throw SportsDeskError.decoding("Line combinations page was not UTF-8 text.")
        }
        let json: Data
        if let jsonData = extractNextData(from: html) {
            json = jsonData
        } else if html.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
            json = data
        } else {
            throw SportsDeskError.decoding("Daily Faceoff page did not include __NEXT_DATA__.")
        }
        let root = try JSONSerialization.jsonObject(with: json)
        return parseRoot(root, sourceName: sourceName)
    }

    static func extractNextData(from html: String) -> Data? {
        guard let startRange = html.range(of: "id=\"__NEXT_DATA__") ?? html.range(of: "id='__NEXT_DATA__") else {
            return nil
        }
        guard let tagEnd = html[startRange.upperBound...].range(of: ">") else { return nil }
        let after = html[tagEnd.upperBound...]
        guard let end = after.range(of: "</script>") else { return nil }
        return String(after[..<end.lowerBound]).data(using: .utf8)
    }

    static func parseRoot(_ root: Any, sourceName: String) -> LineCombinationReport {
        let pageProps = dig(root, ["props", "pageProps"]) as? [String: Any]
        let combo = firstDictionary(in: pageProps, keys: ["lineCombination", "lineCombinations", "lineup", "lines"])
            ?? firstDictionary(in: dig(pageProps as Any, ["data"]) as? [String: Any], keys: ["lineCombination", "lineup", "lines"])
            ?? pageProps

        let note = stringValue(combo?["source"]) ?? stringValue(combo?["sourceNote"])
        let updated = DateParser.parse(stringValue(combo?["updatedAt"]) ?? stringValue(combo?["lastUpdated"]))

        let forwards = parseUnits(
            combo?["forwards"] ?? combo?["forwardLines"] ?? dig(combo as Any, ["evenstrength", "forwards"]),
            titlePrefix: "Line",
            positions: ["LW", "C", "RW"]
        )
        let defense = parseUnits(
            combo?["defense"] ?? combo?["defence"] ?? combo?["defensivePairings"] ?? combo?["defensemen"]
                ?? dig(combo as Any, ["evenstrength", "defense"]),
            titlePrefix: "Pair",
            positions: ["LD", "RD"]
        )
        let goalies = parseUnits(
            combo?["goalies"] ?? combo?["goaltenders"],
            titlePrefix: "Goalie",
            positions: ["G"]
        )

        if forwards.isEmpty && defense.isEmpty && goalies.isEmpty {
            return .unavailable(sourceName: sourceName, reason: "Daily Faceoff did not return a recognizable lineup.")
        }
        return LineCombinationReport(
            sourceName: sourceName,
            updatedAt: updated,
            sourceNote: note,
            forwardLines: forwards,
            defensePairs: defense,
            goalies: goalies
        )
    }

    private static func parseUnits(_ raw: Any?, titlePrefix: String, positions: [String]) -> [LineUnit] {
        guard let raw else { return [] }
        if let rows = raw as? [[String: Any]] {
            return rows.enumerated().compactMap { index, row in
                let players = players(from: row, fallbackPositions: positions)
                guard !players.isEmpty else { return nil }
                return LineUnit(id: "\(titlePrefix.lowercased())-\(index + 1)", title: "\(titlePrefix) \(index + 1)", players: players)
            }
        }
        if let rows = raw as? [[[String: Any]]] {
            return rows.enumerated().compactMap { index, row in
                let players = row.enumerated().compactMap { playerIndex, item -> LinePlayer? in
                    player(from: item, fallbackPosition: positions[safe: playerIndex])
                }
                guard !players.isEmpty else { return nil }
                return LineUnit(id: "\(titlePrefix.lowercased())-\(index + 1)", title: "\(titlePrefix) \(index + 1)", players: players)
            }
        }
        if let singles = raw as? [[String: Any]] {
            let players = singles.compactMap { player(from: $0, fallbackPosition: positions.first) }
            return players.isEmpty ? [] : [LineUnit(id: titlePrefix.lowercased(), title: titlePrefix, players: players)]
        }
        return []
    }

    private static func players(from row: [String: Any], fallbackPositions: [String]) -> [LinePlayer] {
        let keys = ["lw", "c", "rw", "ld", "rd", "g", "left", "center", "right", "starter", "backup"]
        var result: [LinePlayer] = []
        for key in keys {
            if let value = row[key] ?? row[key.uppercased()] {
                let position = positionLabel(for: key)
                if let player = player(from: value, fallbackPosition: position) {
                    result.append(player)
                }
            }
        }
        if result.isEmpty, let name = stringValue(row["name"]) {
            result.append(LinePlayer(id: stringValue(row["id"]), name: name, position: stringValue(row["role"]) ?? stringValue(row["position"])))
        }
        if result.isEmpty {
            let nested = row.values.compactMap { $0 as? [String: Any] }
            result = nested.enumerated().compactMap { index, item in
                player(from: item, fallbackPosition: fallbackPositions[safe: index])
            }
        }
        return result
    }

    private static func player(from raw: Any, fallbackPosition: String?) -> LinePlayer? {
        if let name = raw as? String, !name.isEmpty {
            return LinePlayer(name: name, position: fallbackPosition)
        }
        guard let dict = raw as? [String: Any] else { return nil }
        guard let name = stringValue(dict["name"]) ?? stringValue(dict["displayName"]) ?? fullName(dict) else {
            return nil
        }
        return LinePlayer(
            id: stringValue(dict["id"]),
            name: name,
            position: stringValue(dict["position"]) ?? stringValue(dict["role"]) ?? fallbackPosition
        )
    }

    private static func fullName(_ dict: [String: Any]) -> String? {
        let first = stringValue(dict["firstName"])
        let last = stringValue(dict["lastName"])
        if first == nil && last == nil { return nil }
        return [first, last].compactMap { $0 }.joined(separator: " ")
    }

    private static func positionLabel(for key: String) -> String {
        switch key.lowercased() {
        case "lw", "left": return "LW"
        case "c", "center": return "C"
        case "rw", "right": return "RW"
        case "ld": return "LD"
        case "rd": return "RD"
        case "g", "starter": return "Starter"
        case "backup": return "Backup"
        default: return key.uppercased()
        }
    }

    private static func dig(_ root: Any, _ path: [String]) -> Any? {
        var current: Any? = root
        for key in path {
            current = (current as? [String: Any])?[key]
        }
        return current
    }

    private static func firstDictionary(in dict: [String: Any]?, keys: [String]) -> [String: Any]? {
        guard let dict else { return nil }
        for key in keys {
            if let value = dict[key] as? [String: Any] { return value }
        }
        return nil
    }

    private static func stringValue(_ raw: Any?) -> String? {
        if let text = raw as? String, !text.isEmpty { return text }
        if let number = raw as? NSNumber { return number.stringValue }
        if let dict = raw as? [String: Any] {
            return stringValue(dict["default"]) ?? stringValue(dict["name"])
        }
        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
