import SportsDeskCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isLoading && model.dashboards.isEmpty {
                ProgressView("Loading your teams…")
                    .font(Theme.bodyFont)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.dashboards.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: sectionSpacing) {
                        header
                        ForEach(model.dashboards) { board in
                            NavigationLink(value: board.team.id.description) {
                                TeamSummaryCard(board: board)
                            }
                            #if os(tvOS)
                            .buttonStyle(.card)
                            #else
                            .buttonStyle(.plain)
                            #endif
                        }
                    }
                    .padding(.horizontal, Theme.horizontalPadding)
                    .padding(.vertical, 20)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Sports Desk")
        .navigationDestination(for: String.self) { id in
            if let board = model.dashboards.first(where: { $0.id == id }) {
                TeamDashboardView(board: board)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh")
            }
        }
        #if os(iOS)
        .refreshable { await model.refresh() }
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your teams")
                .font(Theme.titleFont)
            Text(subtitle)
                .font(Theme.bodyFont)
                .foregroundStyle(.secondary)
            if let error = model.errorMessage, !model.dashboards.isEmpty {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("No teams yet")
                .font(Theme.titleFont)
            Text(model.errorMessage ?? "Add a favourite NHL or NFL team in Settings. Your picks sync over iCloud to Apple TV, iPhone, and iPad.")
                .font(Theme.bodyFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var subtitle: String {
        if let last = model.lastUpdated {
            return "Updated \(DateParser.display(date: last))"
        }
        return "Leafs and Packers are the starting lineup. Change them anytime."
    }

    private var sectionSpacing: CGFloat {
        #if os(tvOS)
        28
        #else
        16
        #endif
    }
}

struct TeamSummaryCard: View {
    var board: TeamDashboard

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            RemoteImage(url: board.team.logoURL, size: logoSize)
            VStack(alignment: .leading, spacing: 6) {
                Text(board.team.displayName)
                    .font(Theme.titleFont)
                Text(board.team.league.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(board.team.secondaryColor)
                if let game = board.game {
                    Text(gameLine(game))
                        .font(Theme.bodyFont)
                        .foregroundStyle(.secondary)
                }
                if let record = board.teamStats.items.first(where: { $0.label == "Record" }) {
                    Text(record.value)
                        .font(.headline)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(cardPadding)
        .background(board.team.primaryColor.opacity(0.35), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private func gameLine(_ game: GameSnapshot) -> String {
        switch game.phase {
        case .live:
            return [game.scoreLine, game.periodLabel, game.clock].compactMap { $0 }.joined(separator: " · ")
        case .final:
            return game.scoreLine.map { "Final · \($0)" } ?? "Final"
        case .upcoming:
            let when = game.start.map { DateParser.weekdayTime(date: $0) } ?? game.detailHeadline
            return "\(game.isHome ? "vs" : "@") \(game.opponentName) · \(when)"
        case .unknown:
            return game.opponentName
        }
    }

    private var logoSize: CGFloat {
        #if os(tvOS)
        92
        #else
        56
        #endif
    }

    private var cardPadding: CGFloat {
        #if os(tvOS)
        24
        #else
        14
        #endif
    }
}
