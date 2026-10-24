import SportsDeskCore
import SwiftUI

struct TeamDashboardView: View {
    var board: TeamDashboard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let game = board.game {
                    NavigationLink {
                        GameDetailView(team: board.team, game: game)
                    } label: {
                        GameCard(game: game)
                    }
                    .cardLink()
                }
                NavigationLink {
                    StandingsDetailView(standings: board.standings, team: board.team)
                } label: {
                    StandingsCard(standings: board.standings)
                }
                .cardLink()
                NavigationLink {
                    StatsDetailView(team: board.team, stats: board.teamStats)
                } label: {
                    StatsCard(stats: board.teamStats)
                }
                .cardLink()
                if let lines = board.lines {
                    NavigationLink {
                        LinesDetailView(report: lines, team: board.team)
                    } label: {
                        LinesCard(report: lines)
                    }
                    .cardLink()
                }
                if let depth = board.depthChart {
                    NavigationLink {
                        DepthChartDetailView(report: depth, team: board.team)
                    } label: {
                        DepthChartCard(report: depth)
                    }
                    .cardLink()
                }
                if let injuries = board.injuries {
                    NavigationLink {
                        InjuriesDetailView(report: injuries, team: board.team)
                    } label: {
                        InjuriesCard(report: injuries)
                    }
                    .cardLink()
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(board.team.shortName)
    }

    private var header: some View {
        HStack(spacing: 16) {
            RemoteImage(url: board.team.logoURL, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(board.team.displayName)
                    .font(Theme.titleFont)
                Text([board.team.conference, board.team.division].compactMap { $0 }.joined(separator: " · "))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension View {
    func cardLink() -> some View {
        #if os(tvOS)
        self.buttonStyle(.card)
        #else
        self.buttonStyle(.plain)
        #endif
    }
}
