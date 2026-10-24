import SportsDeskCore
import SwiftUI

struct GameDetailView: View {
    var team: TeamSummary
    var game: GameSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(game.phase == .live ? "Live" : game.phase == .final ? "Boxscore" : "Preview")
                    .font(Theme.titleFont)
                HStack {
                    Text("\(game.awayCode) \(game.awayScore.map(String.init) ?? "—")")
                    Text("@")
                    Text("\(game.homeCode) \(game.homeScore.map(String.init) ?? "—")")
                }
                .font(.largeTitle.weight(.bold))
                labeled("Opponent", game.opponentName)
                if let start = game.start {
                    labeled("Local time", DateParser.display(date: start))
                }
                if let venue = game.venue {
                    labeled("Venue", [venue, game.venueCity].compactMap { $0 }.joined(separator: " · "))
                }
                if !game.broadcasts.isEmpty {
                    labeled("Broadcast", game.broadcasts.map { [$0.network, $0.market].compactMap { $0 }.joined(separator: " ") }.joined(separator: ", "))
                }
                if let period = game.periodLabel {
                    labeled("Period", [period, game.clock].compactMap { $0 }.joined(separator: " · "))
                }
                if !game.notes.isEmpty {
                    section("Matchup notes", game.notes)
                }
                if !game.scoringSummary.isEmpty {
                    section("Scoring", game.scoringSummary)
                }
                if !game.boxscorePlayers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Boxscore").font(.headline)
                        ForEach(game.boxscorePlayers) { player in
                            HStack {
                                Text(player.name)
                                Spacer()
                                Text(player.line).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(team.shortName)
    }
}

struct StandingsDetailView: View {
    var standings: StandingsSnapshot
    var team: TeamSummary

    var body: some View {
        List {
            section("Division", standings.divisionName, standings.divisionRows)
            section("Conference", standings.conferenceName, standings.conferenceRows)
            section("League", standings.league.displayName, standings.leagueRows)
        }
        .navigationTitle("Standings")
    }

    @ViewBuilder
    private func section(_ title: String, _ subtitle: String?, _ rows: [StandingRow]) -> some View {
        SwiftUI.Section(subtitle.map { "\(title) · \($0)" } ?? title) {
            ForEach(rows) { row in
                HStack {
                    Text("\(row.rank)")
                        .frame(width: 28, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(row.team.abbreviation)
                        .fontWeight(row.isFavourite ? .bold : .regular)
                    Spacer()
                    Text(row.record)
                    Text(row.pointsOrPct)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct StatsDetailView: View {
    var team: TeamSummary
    var stats: TeamStatBlock

    var body: some View {
        List {
            SwiftUI.Section("Team") {
                ForEach(stats.items) { item in
                    LabeledContent(item.label, value: item.value)
                    if let detail = item.detail {
                        Text(detail).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            SwiftUI.Section("Players") {
                ForEach(stats.players) { player in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(player.name)
                            if let position = player.position {
                                Text(position).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(player.line)
                        }
                        if let secondary = player.secondary {
                            Text(secondary).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Stats")
    }
}

struct LinesDetailView: View {
    var report: LineCombinationReport
    var team: TeamSummary

    var body: some View {
        List {
            if report.isUnavailable {
                Text(report.unavailableReason ?? "Unavailable")
            } else {
                if let note = report.sourceNote {
                    Text(note).foregroundStyle(.secondary)
                }
                units("Forwards", report.forwardLines)
                units("Defence", report.defensePairs)
                units("Goalies", report.goalies)
            }
        }
        .navigationTitle("Lines")
        .safeAreaInset(edge: .bottom) {
            Text("Source: \(report.sourceName)")
                .font(.footnote)
                .padding()
        }
    }

    @ViewBuilder
    private func units(_ title: String, _ units: [LineUnit]) -> some View {
        if !units.isEmpty {
            SwiftUI.Section(title) {
                ForEach(units) { unit in
                    VStack(alignment: .leading) {
                        Text(unit.title).font(.headline)
                        Text(unit.players.map { [$0.position, $0.name].compactMap { $0 }.joined(separator: " ") }.joined(separator: " · "))
                    }
                }
            }
        }
    }
}

struct DepthChartDetailView: View {
    var report: DepthChartReport
    var team: TeamSummary

    var body: some View {
        List {
            if report.isUnavailable {
                Text(report.unavailableReason ?? "Unavailable")
            } else {
                ForEach(report.units.keys.sorted(), id: \.self) { name in
                    SwiftUI.Section(name) {
                        ForEach(report.units[name] ?? []) { slot in
                            LabeledContent(slot.position, value: slot.playerName)
                        }
                    }
                }
            }
        }
        .navigationTitle("Depth chart")
    }
}

struct InjuriesDetailView: View {
    var report: InjuryReport
    var team: TeamSummary

    var body: some View {
        List {
            if report.isUnavailable {
                Text(report.unavailableReason ?? "Unavailable")
            } else if report.items.isEmpty {
                Text("No players currently listed on the injury report.")
            } else {
                ForEach(report.items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.playerName).font(.headline)
                            Spacer()
                            Text(item.status).fontWeight(.semibold)
                        }
                        Text([item.position, item.injury].compactMap { $0 }.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                        if let comment = item.comment {
                            Text(comment).font(.footnote)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Injury report")
        .safeAreaInset(edge: .bottom) {
            Text("Source: \(report.sourceName)")
                .font(.footnote)
                .padding()
        }
    }
}

private func labeled(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.caption).foregroundStyle(.secondary)
        Text(value).font(Theme.bodyFont)
    }
}

private func section(_ title: String, _ rows: [String]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.headline)
        ForEach(rows, id: \.self) { row in
            Text(row)
        }
    }
}
