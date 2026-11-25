import SportsDeskCore
import SwiftUI

// MARK: - Dashboard spotlight

/// One large card per favourite on the main dashboard: identity, game and a few key numbers.
struct TeamSpotlightCard: View {
    var board: TeamDashboard

    private var team: TeamSummary { board.team }
    private var row: StandingRow? { board.standings.divisionRows.first { $0.isFavourite } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.isTV ? 28 : 16) {
            HStack(spacing: Theme.isTV ? 24 : 14) {
                TeamLogo(team: team, size: Theme.logoMedium)
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.displayName)
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
            }

            if let game = board.game {
                GameHeroCard(team: team, game: game, showsChevron: false)
            } else {
                UnavailableNote(message: "No games this week. Enjoy the break.", systemImage: "calendar.badge.clock")
                    .padding(.vertical, 8)
            }

            HStack(spacing: 10) {
                ForEach(keyStats) { item in
                    StatTile(label: item.label, value: item.value, detail: item.detail)
                }
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface(tint: team.accentColor)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the \(team.shortName) page")
    }

    private var subtitle: String {
        var parts = [team.league.displayName]
        if let division = team.division {
            parts.append(row.map { "\(ordinal($0.rank)) in \(division)" } ?? division)
        }
        return parts.joined(separator: " · ")
    }

    private var keyStats: [StatLine] {
        var stats: [StatLine] = []
        if let row {
            stats.append(StatLine(label: "Record", value: row.record))
            stats.append(StatLine(label: team.league == .nhl ? "Points" : "Win %", value: row.pointsOrPct.replacingOccurrences(of: " pts", with: "")))
            if let streak = row.streak { stats.append(StatLine(label: "Streak", value: streak)) }
        }
        return Array(stats.prefix(3))
    }
}

func ordinal(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .ordinal
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

struct TeamErrorCard: View {
    var failure: DashboardFailure
    var retry: () -> Void

    var body: some View {
        let team = TeamCatalog.shared.team(for: failure.favourite.teamID)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                TeamLogo(url: team?.logoURL, abbreviation: failure.favourite.code, size: Theme.logoMedium)
                    .saturation(0.2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(failure.teamName).font(.title3.weight(.bold))
                    Text("Couldn't load right now").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text(failure.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Button(action: retry) {
                Label("Try again", systemImage: "arrow.clockwise")
            }
            #if os(iOS)
            .buttonStyle(.bordered)
            #endif
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface(tint: .orange)
    }
}

// MARK: - Team page cards

struct StandingsCard: View {
    var standings: StandingsSnapshot
    var team: TeamSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: standings.divisionName ?? "Standings", systemImage: "list.number", tint: team.accentColor)
            if standings.divisionRows.isEmpty {
                UnavailableNote(message: "Standings aren't published yet.")
            } else {
                StandingsTable(rows: standings.divisionRows, league: standings.league, accent: team.accentColor, compact: true)
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface()
    }
}

struct StatsCard: View {
    var stats: TeamStatBlock
    var team: TeamSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Team stats", systemImage: "chart.bar.fill", tint: team.accentColor)
            if stats.items.isEmpty {
                UnavailableNote(message: "Season stats will appear after the first game.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.isTV ? 200 : 96), spacing: 8)], spacing: 8) {
                    ForEach(stats.items.prefix(6)) { item in
                        StatTile(label: item.label, value: item.value)
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface()
    }
}

struct LeadersCard: View {
    var stats: TeamStatBlock
    var team: TeamSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Leaders", systemImage: "star.fill", tint: team.accentColor)
            if stats.players.isEmpty {
                UnavailableNote(message: "No player stats yet.")
            } else {
                ForEach(stats.players.prefix(4)) { player in
                    PlayerRow(player: player, tint: team.accentColor)
                }
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface()
    }
}

struct PlayerRow: View {
    var player: PlayerStat
    var tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Headshot(url: player.headshotURL, name: player.name, tint: tint, size: Theme.isTV ? 64 : 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(player.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if let position = player.position {
                        Text(position).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    }
                }
                if let secondary = player.secondary {
                    Text(secondary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(player.line)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

struct LinesCard: View {
    var report: LineCombinationReport
    var team: TeamSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Lines", systemImage: "person.3.fill", tint: team.accentColor)
            if report.isUnavailable {
                UnavailableNote(message: report.unavailableReason ?? "Line combinations are unavailable.", systemImage: "wifi.exclamationmark")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if let first = report.forwardLines.first { unit("F1", first) }
                    if let pair = report.defensePairs.first { unit("D1", pair) }
                    if let goalie = report.goalies.first?.players.first {
                        HStack {
                            Text("G").font(.caption.weight(.heavy)).foregroundStyle(team.accentColor).frame(width: 28, alignment: .leading)
                            Text(goalie.name).font(.subheadline)
                        }
                    }
                }
                SourceFootnote(source: report.sourceName, updated: report.updatedAt)
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface()
    }

    private func unit(_ label: String, _ unit: LineUnit) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.caption.weight(.heavy)).foregroundStyle(team.accentColor).frame(width: 28, alignment: .leading)
            Text(unit.players.map(\.name).joined(separator: " · "))
                .font(.subheadline)
                .lineLimit(2)
        }
    }
}

struct DepthChartCard: View {
    var report: DepthChartReport
    var team: TeamSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Starters", systemImage: "person.3.sequence.fill", tint: team.accentColor)
            if report.isUnavailable || report.starters.isEmpty {
                UnavailableNote(message: report.unavailableReason ?? "Depth chart unavailable.")
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 8) {
                    ForEach(report.starters.prefix(8)) { slot in
                        HStack(spacing: 8) {
                            Text(slot.position)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(team.accentColor)
                                .frame(width: Theme.isTV ? 64 : 36, alignment: .leading)
                            Text(slot.playerName).font(.subheadline).lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface()
    }
}

struct InjuriesCard: View {
    var report: InjuryReport
    var team: TeamSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Key injuries", systemImage: "cross.case.fill", tint: .red)
            if report.isUnavailable {
                UnavailableNote(message: report.unavailableReason ?? "Injury report unavailable.", systemImage: "wifi.exclamationmark")
            } else if report.keyItems.isEmpty {
                UnavailableNote(message: "Clean bill of health — no notable designations.", systemImage: "checkmark.seal")
            } else {
                ForEach(report.keyItems.prefix(4)) { item in
                    InjuryRow(item: item, showsComment: false)
                }
                if report.keyItems.count > 4 {
                    Text("+\(report.keyItems.count - 4) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface()
    }
}

struct InjuryRow: View {
    var item: InjuryItem
    var showsComment: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.playerName).font(.subheadline.weight(.semibold))
                    let detail = [item.position, item.injury].compactMap { $0 }.joined(separator: " · ")
                    if !detail.isEmpty {
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Pill(text: item.status, tint: Theme.statusColor(item.status))
            }
            if showsComment, let comment = item.comment {
                Text(comment).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Standings table

struct StandingsTable: View {
    var rows: [StandingRow]
    var league: League
    var accent: Color
    var compact = false

    /// Roughly one digit wide at the current text size; columns scale with Dynamic Type.
    @ScaledMetric(relativeTo: .subheadline) private var digit: CGFloat = Theme.isTV ? 18 : 9

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: spacing) {
                cell("#", width: digit * 2.4)
                Text("TEAM").frame(maxWidth: .infinity, alignment: .leading)
                if !compact { cell("GP", width: digit * 3) }
                cell(league == .nhl ? "W-L-OT" : "W-L", width: digit * (league == .nhl ? 7 : 5.5))
                cell(league == .nhl ? "PTS" : "PCT", width: digit * 4)
                cell("DIFF", width: digit * 4)
                if !compact { cell("STRK", width: digit * 4) }
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)
            .padding(.horizontal, 6)
            .accessibilityHidden(true)

            ForEach(rows) { row in
                HStack(spacing: spacing) {
                    cell("\(row.rank)", width: digit * 2.4).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TeamLogo(team: row.team, size: Theme.logoSmall)
                        Text(compact ? row.team.abbreviation : row.team.shortName)
                            .fontWeight(row.isFavourite ? .bold : .regular)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !compact { cell("\(row.gamesPlayed)", width: digit * 3) }
                    cell(row.record, width: digit * (league == .nhl ? 7 : 5.5))
                    cell(row.pointsOrPct.replacingOccurrences(of: " pts", with: ""), width: digit * 4).fontWeight(.semibold)
                    cell(diff(row), width: digit * 4).foregroundStyle(diffColor(row))
                    if !compact { cell(row.streak ?? "—", width: digit * 4).foregroundStyle(.secondary) }
                }
                .font(.subheadline)
                .monospacedDigit()
                .padding(.vertical, Theme.isTV ? 10 : 6)
                .padding(.horizontal, 6)
                .background {
                    if row.isFavourite {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accent.opacity(0.22))
                    }
                }
                .tvFocusableRow()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(row))
            }
        }
    }

    private var spacing: CGFloat { Theme.isTV ? 24 : 8 }

    private func cell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: width, alignment: .trailing)
    }

    private func diffValue(_ row: StandingRow) -> Int? {
        guard let scored = Int(row.pointsFor), let allowed = Int(row.pointsAgainst) else { return nil }
        return scored - allowed
    }

    private func diff(_ row: StandingRow) -> String {
        guard let value = diffValue(row) else { return "—" }
        return value > 0 ? "+\(value)" : "\(value)"
    }

    private func diffColor(_ row: StandingRow) -> Color {
        guard let value = diffValue(row), value != 0 else { return .secondary }
        return value > 0 ? Theme.win : Theme.loss
    }

    private func accessibilityLabel(_ row: StandingRow) -> String {
        var text = "\(ordinal(row.rank)), \(row.team.displayName), \(row.record), \(row.pointsOrPct)"
        if row.isFavourite { text += ", your team" }
        return text
    }
}
