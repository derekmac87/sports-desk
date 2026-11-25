import SportsDeskCore
import SwiftUI

enum AppTab: Hashable {
    case dashboard, settings
}

/// Routes carry ids, not snapshots, so detail screens keep updating while a game is live.
enum Route: Hashable {
    case team(String)
    case game(String)
    case standings(String)
    case stats(String)
    case lines(String)
    case depthChart(String)
    case injuries(String)
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                DashboardView(openSettings: { tab = .settings })
                    .navigationDestination(for: Route.self) { route in
                        RouteDestination(route: route)
                    }
            }
            .tabItem { Label("Scores", systemImage: "sportscourt.fill") }
            .tag(AppTab.dashboard)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Teams", systemImage: "star.fill") }
            .tag(AppTab.settings)
        }
        .tint(.white)
        .task { await model.bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.sceneBecameActive()
            case .background: model.sceneWentToBackground()
            default: break
            }
        }
    }
}

private struct RouteDestination: View {
    @EnvironmentObject private var model: AppModel
    var route: Route

    var body: some View {
        switch route {
        case .team(let id):
            withBoard(id) { TeamDashboardView(board: $0) }
        case .game(let id):
            withBoard(id) { board in
                if let game = board.game {
                    GameDetailView(team: board.team, game: game)
                } else {
                    missing("No game scheduled", "\(board.team.shortName) don't have an upcoming game this week.")
                }
            }
        case .standings(let id):
            withBoard(id) { StandingsDetailView(standings: $0.standings, team: $0.team) }
        case .stats(let id):
            withBoard(id) { StatsDetailView(team: $0.team, stats: $0.teamStats) }
        case .lines(let id):
            withBoard(id) { board in
                if let lines = board.lines { LinesDetailView(report: lines, team: board.team) }
            }
        case .depthChart(let id):
            withBoard(id) { board in
                if let depth = board.depthChart { DepthChartDetailView(report: depth, team: board.team) }
            }
        case .injuries(let id):
            withBoard(id) { board in
                if let injuries = board.injuries { InjuriesDetailView(report: injuries, team: board.team) }
            }
        }
    }

    @ViewBuilder
    private func withBoard<Content: View>(_ id: String, @ViewBuilder content: (TeamDashboard) -> Content) -> some View {
        if let board = model.board(id: id) {
            content(board)
        } else {
            missing("Team removed", "This team is no longer in your favourites.")
        }
    }

    private func missing(_ title: String, _ message: String) -> some View {
        ContentUnavailableView(title, systemImage: "questionmark.circle", description: Text(message))
    }
}
