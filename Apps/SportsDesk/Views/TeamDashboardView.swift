import SportsDeskCore
import SwiftUI

struct TeamDashboardView: View {
    var board: TeamDashboard

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var team: TeamSummary { board.team }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                TeamHeroHeader(board: board)

                if let game = board.game {
                    NavigationLink(value: Route.game(board.id)) {
                        GameHeroCard(team: team, game: game)
                    }
                    .cardLinkStyle()
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.gridSpacing) {
                    link(.standings(board.id)) { StandingsCard(standings: board.standings, team: team) }
                    link(.stats(board.id)) { StatsCard(stats: board.teamStats, team: team) }
                    link(.stats(board.id)) { LeadersCard(stats: board.teamStats, team: team) }
                    if let lines = board.lines {
                        link(.lines(board.id)) { LinesCard(report: lines, team: team) }
                    }
                    if let depth = board.depthChart {
                        link(.depthChart(board.id)) { DepthChartCard(report: depth, team: team) }
                    }
                    if let injuries = board.injuries {
                        link(.injuries(board.id)) { InjuriesCard(report: injuries, team: team) }
                    }
                }
                .tvFocusSection()

                Text("Updated \(board.fetchedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AmbientBackground(colors: [team.primaryColor, team.secondaryColor]))
        .navigationTitle(team.shortName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func link<Content: View>(_ route: Route, @ViewBuilder content: () -> Content) -> some View {
        NavigationLink(value: route, label: content)
            .cardLinkStyle()
    }

    private var columns: [GridItem] {
        #if os(tvOS)
        [GridItem(.adaptive(minimum: 520), spacing: Theme.gridSpacing, alignment: .top)]
        #else
        sizeClass == .regular
            ? [GridItem(.adaptive(minimum: 340), spacing: Theme.gridSpacing, alignment: .top)]
            : [GridItem(.flexible(), alignment: .top)]
        #endif
    }
}

private struct TeamHeroHeader: View {
    var board: TeamDashboard

    private var team: TeamSummary { board.team }
    private var row: StandingRow? { board.standings.divisionRows.first { $0.isFavourite } }

    var body: some View {
        HStack(spacing: Theme.isTV ? 40 : 18) {
            TeamLogo(team: team, size: Theme.logoLarge)
            VStack(alignment: .leading, spacing: 6) {
                Text(team.city.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.75))
                Text(team.shortName)
                    .font(.largeTitle.weight(.heavy))
                    .fontDesign(.rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 8) {
                    if let row {
                        Pill(text: row.record, tint: .white)
                        Pill(text: "\(ordinal(row.rank)) \(team.division ?? "")", tint: .white)
                        if let streak = row.streak { Pill(text: streak, systemImage: "flame.fill", tint: .white) }
                    } else {
                        Pill(text: team.league.displayName, systemImage: team.league.symbolName, tint: .white)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .trailing) {
                team.gradient
                TeamLogo(team: team, size: Theme.logoLarge * 2.2)
                    .opacity(0.12)
                    .offset(x: Theme.logoLarge * 0.6)
                    .blendMode(.plusLighter)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .padding(.top, Theme.isTV ? 0 : 8)
        .accessibilityElement(children: .combine)
    }
}
