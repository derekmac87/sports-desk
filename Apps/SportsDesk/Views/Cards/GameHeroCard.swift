import SportsDeskCore
import SwiftUI

/// Scoreboard-style card for the live, just-finished or next game.
struct GameHeroCard: View {
    var team: TeamSummary
    var game: GameSnapshot
    var showsChevron = true

    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = Theme.isTV ? 110 : 56
    @ScaledMetric(relativeTo: .title) private var logoSize: CGFloat = Theme.isTV ? 150 : 64

    private var opponent: TeamSummary? { TeamSummary.lookup(league: team.league, code: game.opponentCode) }
    private var awayTeam: TeamSummary? { game.isHome ? opponent : team }
    private var homeTeam: TeamSummary? { game.isHome ? team : opponent }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.isTV ? 28 : 16) {
            statusRow
            HStack(alignment: .center, spacing: 0) {
                side(team: awayTeam, code: game.awayCode, score: game.awayScore, logo: game.isHome ? game.opponentLogoURL : team.logoURL)
                centre
                side(team: homeTeam, code: game.homeCode, score: game.homeScore, logo: game.isHome ? team.logoURL : game.opponentLogoURL)
            }
            footer
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(game.phase == .live ? Theme.live.opacity(0.6) : .white.opacity(0.1), lineWidth: game.phase == .live ? 1.5 : 1)
        }
        .animation(.smooth, value: game)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(showsChevron ? "Opens game details" : "")
    }

    // MARK: Pieces

    private var statusRow: some View {
        HStack(spacing: 10) {
            switch game.phase {
            case .live:
                LiveBadge()
                Text(liveStatus)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            case .final:
                Pill(text: game.detailHeadline.uppercased(), tint: .white)
                if let outcome = game.outcome {
                    Pill(text: outcome, tint: outcome == "W" ? Theme.win : (outcome == "L" ? Theme.loss : .white))
                }
            case .upcoming:
                Pill(text: "NEXT GAME", systemImage: "calendar", tint: .white)
            case .unknown:
                Pill(text: game.detailHeadline.uppercased(), tint: .white)
            }
            Spacer(minLength: 0)
            Label(team.league.displayName, systemImage: team.league.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func side(team: TeamSummary?, code: String, score: Int?, logo: URL?) -> some View {
        let isLoser = game.phase == .final && score != nil && score! < max(game.homeScore ?? 0, game.awayScore ?? 0)
        return VStack(spacing: Theme.isTV ? 12 : 6) {
            TeamLogo(url: logo, abbreviation: code, size: logoSize)
            Text(code)
                .font(.headline.weight(.heavy))
                .tracking(0.5)
            Text(team?.shortName ?? " ")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
            if game.phase != .upcoming, let score {
                Text("\(score)")
                    .font(.system(size: scoreSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(score)))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .opacity(isLoser ? 0.55 : 1)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var centre: some View {
        VStack(spacing: 6) {
            switch game.phase {
            case .upcoming:
                if let start = game.start, start > .now {
                    Text(team.league.startVerb.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.7))
                    CountdownText(start: start, font: .system(Theme.isTV ? .largeTitle : .title2, design: .rounded).weight(.bold))
                } else {
                    Text(game.isHome ? "vs" : "@")
                        .font(.title2.weight(.bold))
                    Text("Starting soon")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            default:
                Text(game.isHome ? "vs" : "@")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(minWidth: Theme.isTV ? 220 : 90)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let start = game.start {
                    Label(GameTimeFormatting.startLabel(for: start), systemImage: "clock")
                }
                if let venue = game.venue {
                    Text("·")
                    Text(venue).lineLimit(1)
                }
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.8))

            if !game.broadcasts.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "tv")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    ForEach(Array(Set(game.broadcasts.map(\.network))).sorted().prefix(4), id: \.self) { network in
                        Text(network)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }
        }
    }

    private var background: some View {
        let away = awayTeam?.primaryColor ?? .gray
        let home = homeTeam?.primaryColor ?? .gray
        return ZStack {
            LinearGradient(colors: [away, home], startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(.ultraThinMaterial).opacity(0.35)
        }
    }

    // MARK: Text

    private var liveStatus: String {
        let periodClock = [game.periodLabel, game.clock].compactMap { $0 }.joined(separator: " ")
        return periodClock.isEmpty ? game.detailHeadline : periodClock
    }

    private var accessibilitySummary: String {
        let away = awayTeam?.displayName ?? game.awayCode
        let home = homeTeam?.displayName ?? game.homeCode
        switch game.phase {
        case .live:
            return "Live. \(away) \(game.awayScore ?? 0), \(home) \(game.homeScore ?? 0). \(game.detailHeadline)."
        case .final:
            return "\(game.detailHeadline). \(away) \(game.awayScore ?? 0), \(home) \(game.homeScore ?? 0)."
        case .upcoming, .unknown:
            let when = game.start.map { GameTimeFormatting.startLabel(for: $0) } ?? game.detailHeadline
            let tv = game.broadcasts.isEmpty ? "" : " On \(game.broadcasts.map(\.network).joined(separator: ", "))."
            return "Next game: \(away) at \(home), \(when).\(tv)"
        }
    }
}
