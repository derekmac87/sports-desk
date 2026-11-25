import SportsDeskCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    var openSettings: () -> Void

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                header
                content
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AmbientBackground(colors: model.dashboards.prefix(2).map(\.team.primaryColor)))
        #if os(iOS)
        .refreshable { await model.refresh() }
        .navigationTitle("Sports Desk")
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text("Sports Desk")
                    .font(.largeTitle.weight(.heavy))
                    .fontDesign(.rounded)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if model.isLoading && model.hasLoaded {
                    ProgressView()
                        .accessibilityLabel("Refreshing")
                } else if let updated = model.lastUpdated {
                    (Text("Updated ") + Text(updated, style: .relative) + Text(" ago"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #if os(tvOS)
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                #endif
            }
        }
        .padding(.top, Theme.isTV ? 0 : 12)
        .tvFocusSection()
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if model.settings.favourites.isEmpty {
            ContentUnavailableView {
                Label("Pick your teams", systemImage: "star")
            } description: {
                Text("Follow any NHL or NFL team. Your picks sync over iCloud to Apple TV, iPhone and iPad.")
            } actions: {
                Button("Choose teams", action: openSettings)
                    #if os(iOS)
                    .buttonStyle(.borderedProminent)
                    #endif
            }
            .padding(.top, 60)
        } else if !model.hasLoaded {
            LazyVGrid(columns: columns, spacing: Theme.gridSpacing) {
                ForEach(model.settings.favourites) { _ in TeamCardSkeleton() }
            }
            .transition(.opacity)
        } else if model.dashboards.isEmpty && !model.failures.isEmpty {
            ContentUnavailableView {
                Label("Scores are offline", systemImage: "wifi.exclamationmark")
            } description: {
                Text("We couldn't reach the NHL or ESPN feeds. Check your connection and try again.")
            } actions: {
                Button("Try again") { Task { await model.refresh() } }
                    #if os(iOS)
                    .buttonStyle(.borderedProminent)
                    #endif
            }
            .padding(.top, 60)
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.gridSpacing) {
                ForEach(model.dashboards) { board in
                    NavigationLink(value: Route.team(board.id)) {
                        TeamSpotlightCard(board: board)
                    }
                    .cardLinkStyle()
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
                ForEach(model.failures) { failure in
                    TeamErrorCard(failure: failure) { Task { await model.refresh() } }
                }
            }
            .tvFocusSection()
            .animation(.smooth, value: model.dashboards.map(\.id))
        }
    }

    private var columns: [GridItem] {
        #if os(tvOS)
        [GridItem(.adaptive(minimum: 700), spacing: Theme.gridSpacing, alignment: .top)]
        #else
        sizeClass == .regular
            ? [GridItem(.adaptive(minimum: 420), spacing: Theme.gridSpacing, alignment: .top)]
            : [GridItem(.flexible(), alignment: .top)]
        #endif
    }
}
