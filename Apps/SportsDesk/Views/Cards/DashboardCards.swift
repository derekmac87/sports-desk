import SportsDeskCore
import SwiftUI

struct GameCard: View {
    var game: GameSnapshot

    var body: some View {
        card(title: gameTitle) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(game.isHome ? "vs \(game.opponentName)" : "@ \(game.opponentName)")
                        .font(Theme.titleFont)
                    if let score = game.scoreLine {
                        Text(score).font(.title.weight(.bold))
                    }
                    Text(game.detailHeadline)
                        .foregroundStyle(.secondary)
                    if let venue = game.venue {
                        Text(venue).foregroundStyle(.secondary)
                    }
                    if !game.broadcasts.isEmpty {
                        Text(game.broadcasts.map(\.network).joined(separator: ", "))
                    }
                }
                Spacer()
                RemoteImage(url: game.opponentLogoURL, size: 56)
            }
        }
    }

    private var gameTitle: String {
        switch game.phase {
        case .live: return "Live game"
        case .final: return "Last game"
        case .upcoming: return "Next game"
        case .unknown: return "Game"
        }
    }
}

struct StandingsCard: View {
    var standings: StandingsSnapshot

    var body: some View {
        card(title: "Standings") {
            VStack(alignment: .leading, spacing: 8) {
                if let division = standings.divisionName {
                    Text(division).font(.headline)
                }
                ForEach(standings.divisionRows.prefix(4)) { row in
                    HStack {
                        Text("\(row.rank). \(row.team.abbreviation)")
                            .fontWeight(row.isFavourite ? .bold : .regular)
                        Spacer()
                        Text(row.record)
                        Text(row.pointsOrPct)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("League, conference, and division — tap for the full table.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatsCard: View {
    var stats: TeamStatBlock

    var body: some View {
        card(title: "Team & player stats") {
            VStack(alignment: .leading, spacing: 10) {
                Text(stats.headline).font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading) {
                    ForEach(stats.items.prefix(6)) { item in
                        VStack(alignment: .leading) {
                            Text(item.label).font(.caption).foregroundStyle(.secondary)
                            Text(item.value).font(.headline)
                        }
                    }
                }
                ForEach(stats.players.prefix(3)) { player in
                    HStack {
                        Text(player.name)
                        Spacer()
                        Text(player.line).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct LinesCard: View {
    var report: LineCombinationReport

    var body: some View {
        card(title: "Lines") {
            if report.isUnavailable {
                Text(report.unavailableReason ?? "Line combinations are unavailable.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let first = report.forwardLines.first {
                        Text(first.players.map(\.name).joined(separator: " — "))
                    }
                    if let pair = report.defensePairs.first {
                        Text(pair.players.map(\.name).joined(separator: " — "))
                            .foregroundStyle(.secondary)
                    }
                    if let goalie = report.goalies.first?.players.first {
                        Text("G \(goalie.name)")
                    }
                    Text("Source: \(report.sourceName)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct DepthChartCard: View {
    var report: DepthChartReport

    var body: some View {
        card(title: "Depth chart / starters") {
            if report.isUnavailable {
                Text(report.unavailableReason ?? "Depth chart unavailable.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(report.starters.prefix(8)) { slot in
                        HStack {
                            Text(slot.position).frame(width: 44, alignment: .leading).foregroundStyle(.secondary)
                            Text(slot.playerName)
                        }
                    }
                }
            }
        }
    }
}

struct InjuriesCard: View {
    var report: InjuryReport

    var body: some View {
        card(title: "Key injuries") {
            if report.isUnavailable {
                Text(report.unavailableReason ?? "Injury report unavailable.")
                    .foregroundStyle(.secondary)
            } else if report.keyItems.isEmpty {
                Text("No notable designations. Tap for the full report.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(report.keyItems.prefix(5)) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading) {
                                Text(item.playerName).fontWeight(.semibold)
                                Text([item.position, item.injury].compactMap { $0 }.joined(separator: " · "))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.status)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(statusColor(item.status))
                        }
                    }
                }
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case let value where value.contains("out"): return .red
        case let value where value.contains("doubt"): return .orange
        case let value where value.contains("question"): return .yellow
        case let value where value.contains("ir") || value.contains("reserve"): return .pink
        default: return .secondary
        }
    }
}

@ViewBuilder
func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        content()
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
}
