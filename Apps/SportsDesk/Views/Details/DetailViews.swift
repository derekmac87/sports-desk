import SportsDeskCore
import SwiftUI

/// Shared scaffold: team-tinted background, readable width on iPad, scrollable on tvOS.
private struct DetailScaffold<Content: View>: View {
    var title: String
    var team: TeamSummary
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                content
            }
            .frame(maxWidth: Theme.isTV ? CGFloat.infinity : 820)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(AmbientBackground(colors: [team.primaryColor]))
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct SectionCard<Content: View>: View {
    var title: String
    var systemImage: String
    var tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: title, systemImage: systemImage, tint: tint, showsChevron: false)
            content
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

// MARK: - Game

struct GameDetailView: View {
    var team: TeamSummary
    var game: GameSnapshot

    var body: some View {
        DetailScaffold(title: title, team: team) {
            GameHeroCard(team: team, game: game, showsChevron: false)
                .tvFocusableRow()

            SectionCard(title: "Game info", systemImage: "info.circle.fill", tint: team.accentColor) {
                if let start = game.start {
                    infoRow("Starts", start.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                }
                if let venue = game.venue {
                    infoRow("Venue", [venue, game.venueCity].compactMap { $0 }.joined(separator: " · "), systemImage: "mappin.and.ellipse")
                }
                if !game.broadcasts.isEmpty {
                    infoRow("Watch", game.broadcasts.map { [$0.network, $0.market].compactMap { $0 }.joined(separator: " ") }.joined(separator: ", "), systemImage: "tv")
                }
                infoRow("Matchup", "\(game.isHome ? "vs" : "@") \(game.opponentName)", systemImage: "sportscourt")
            }

            if !game.scoringSummary.isEmpty {
                SectionCard(title: "Scoring", systemImage: "flag.checkered", tint: team.accentColor) {
                    ForEach(Array(game.scoringSummary.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .tvFocusableRow()
                    }
                }
            }

            if !game.notes.isEmpty {
                SectionCard(title: game.phase == .live ? "Situation" : "Matchup notes", systemImage: "text.bubble.fill", tint: team.accentColor) {
                    ForEach(Array(game.notes.enumerated()), id: \.offset) { _, note in
                        Text(note)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tvFocusableRow()
                    }
                }
            }

            SectionCard(title: "\(team.shortName) boxscore", systemImage: "list.bullet.rectangle", tint: team.accentColor) {
                if game.boxscorePlayers.isEmpty {
                    UnavailableNote(message: game.phase == .upcoming ? "Player stats appear once the game starts." : "No boxscore available for this game.", systemImage: "clock")
                } else {
                    ForEach(game.boxscorePlayers) { player in
                        PlayerRow(player: player, tint: team.accentColor).tvFocusableRow()
                    }
                }
            }
        }
    }

    private var title: String {
        switch game.phase {
        case .live: return "Live"
        case .final: return "Final"
        case .upcoming, .unknown: return "Preview"
        }
    }

    private func infoRow(_ label: String, _ value: String, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: Theme.isTV ? 40 : 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.body)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .tvFocusableRow()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Standings

struct StandingsDetailView: View {
    var standings: StandingsSnapshot
    var team: TeamSummary

    enum Scope: String, CaseIterable, Identifiable {
        case division = "Division", conference = "Conference", league = "League"
        var id: String { rawValue }
    }

    @State private var scope: Scope = .division

    var body: some View {
        DetailScaffold(title: "Standings", team: team) {
            Picker("Standings", selection: $scope) {
                ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .tvFocusSection()

            SectionCard(title: heading, systemImage: "list.number", tint: team.accentColor) {
                if rows.isEmpty {
                    UnavailableNote(message: "Standings aren't published yet — check back once the season starts.")
                } else {
                    StandingsTable(rows: rows, league: standings.league, accent: team.accentColor)
                }
            }
            .animation(.smooth, value: scope)

            if let asOf = standings.asOf {
                Text("As of \(asOf.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var rows: [StandingRow] {
        switch scope {
        case .division: return standings.divisionRows
        case .conference: return standings.conferenceRows
        case .league: return standings.leagueRows
        }
    }

    private var heading: String {
        switch scope {
        case .division: return standings.divisionName ?? "Division"
        case .conference: return standings.conferenceName.map { "\($0) Conference" } ?? "Conference"
        case .league: return standings.league.displayName
        }
    }
}

// MARK: - Stats

struct StatsDetailView: View {
    var team: TeamSummary
    var stats: TeamStatBlock

    var body: some View {
        DetailScaffold(title: "Stats", team: team) {
            SectionCard(title: "Team", systemImage: "chart.bar.fill", tint: team.accentColor) {
                if stats.items.isEmpty {
                    UnavailableNote(message: "Season stats will appear after the first game.")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.isTV ? 260 : 130), spacing: 10)], spacing: 10) {
                        ForEach(stats.items) { item in
                            StatTile(label: item.label, value: item.value, detail: item.detail)
                                .tvFocusableRow()
                        }
                    }
                }
            }
            SectionCard(title: "Players", systemImage: "person.2.fill", tint: team.accentColor) {
                if stats.players.isEmpty {
                    UnavailableNote(message: "No player stats yet.")
                } else {
                    ForEach(stats.players) { player in
                        PlayerRow(player: player, tint: team.accentColor)
                            .padding(.vertical, 4)
                            .tvFocusableRow()
                        if player.id != stats.players.last?.id { Divider().opacity(0.4) }
                    }
                }
            }
        }
    }
}

// MARK: - Lines

struct LinesDetailView: View {
    var report: LineCombinationReport
    var team: TeamSummary

    var body: some View {
        DetailScaffold(title: "Lines", team: team) {
            if report.isUnavailable {
                ContentUnavailableView {
                    Label("Lines unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(report.unavailableReason ?? "Daily Faceoff didn't respond. It often blocks automated requests; try again later.")
                }
                .tvFocusableRow()
            } else {
                if let note = report.sourceNote {
                    UnavailableNote(message: note, systemImage: "info.circle")
                }
                units("Forwards", "figure.hockey", report.forwardLines)
                units("Defence", "shield.lefthalf.filled", report.defensePairs)
                units("Goalies", "hockey.puck", report.goalies)
            }
            SourceFootnote(source: report.sourceName, updated: report.updatedAt)
        }
    }

    @ViewBuilder
    private func units(_ title: String, _ symbol: String, _ units: [LineUnit]) -> some View {
        if !units.isEmpty {
            SectionCard(title: title, systemImage: symbol, tint: team.accentColor) {
                ForEach(units) { unit in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(unit.title.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(unit.players) { player in
                                VStack(spacing: 2) {
                                    Text(player.position ?? "")
                                        .font(.caption2.weight(.heavy))
                                        .foregroundStyle(team.accentColor)
                                    Text(player.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .tvFocusableRow()
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: - Depth chart

struct DepthChartDetailView: View {
    var report: DepthChartReport
    var team: TeamSummary

    var body: some View {
        DetailScaffold(title: "Depth chart", team: team) {
            if report.isUnavailable || report.unitOrder.isEmpty {
                ContentUnavailableView("Depth chart unavailable", systemImage: "person.3.sequence", description: Text(report.unavailableReason ?? "ESPN hasn't published a depth chart."))
                    .tvFocusableRow()
            } else {
                ForEach(report.unitOrder, id: \.self) { name in
                    SectionCard(title: name, systemImage: "person.3.sequence.fill", tint: team.accentColor) {
                        ForEach(report.units[name] ?? []) { slot in
                            HStack {
                                Text(slot.position)
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(team.accentColor)
                                    .frame(width: Theme.isTV ? 90 : 52, alignment: .leading)
                                Text(slot.playerName).font(.subheadline)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 3)
                            .tvFocusableRow()
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            SourceFootnote(source: report.sourceName, updated: nil)
        }
    }
}

// MARK: - Injuries

struct InjuriesDetailView: View {
    var report: InjuryReport
    var team: TeamSummary

    var body: some View {
        DetailScaffold(title: "Injury report", team: team) {
            if report.isUnavailable {
                ContentUnavailableView("Injury report unavailable", systemImage: "wifi.exclamationmark", description: Text(report.unavailableReason ?? ""))
                    .tvFocusableRow()
            } else if report.items.isEmpty {
                ContentUnavailableView("All healthy", systemImage: "checkmark.seal", description: Text("No \(team.shortName) players are on the injury report."))
                    .tvFocusableRow()
            } else {
                SectionCard(title: "\(report.items.count) players listed", systemImage: "cross.case.fill", tint: .red) {
                    ForEach(report.items) { item in
                        InjuryRow(item: item, showsComment: true)
                            .padding(.vertical, 4)
                            .tvFocusableRow()
                        if item.id != report.items.last?.id { Divider().opacity(0.4) }
                    }
                }
            }
            SourceFootnote(source: report.sourceName, updated: nil)
        }
    }
}
