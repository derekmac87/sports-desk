import SportsDeskCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var league: League = .nhl
    @State private var search = ""
    @State private var editing: FavouriteTeam?

    var body: some View {
        List {
            Section {
                if model.settings.favourites.isEmpty {
                    Label("No favourites yet — add a team below.", systemImage: "star")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.settings.favourites) { favourite in
                    favouriteRow(favourite)
                }
                #if os(iOS)
                .onDelete { model.removeFavourites(at: $0) }
                .onMove { model.moveFavourite(from: $0, to: $1) }
                #endif
            } header: {
                Text("Your teams")
            } footer: {
                #if os(iOS)
                Text("Swipe to remove. Tap Edit to reorder — the dashboard follows this order.")
                #else
                Text("Select a team to reorder or remove it. The dashboard follows this order.")
                #endif
            }

            Section {
                Picker("League", selection: $league) {
                    Text("NHL").tag(League.nhl)
                    Text("NFL").tag(League.nfl)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Add a team")
            }

            ForEach(divisions, id: \.name) { division in
                Section(division.name) {
                    ForEach(division.teams) { team in
                        addRow(team)
                    }
                }
            }

            Section {
                LabeledContent("iCloud") {
                    Label(model.isICloudAvailable ? "Syncing" : "Signed out", systemImage: model.isICloudAvailable ? "checkmark.icloud" : "xmark.icloud")
                        .foregroundStyle(model.isICloudAvailable ? Color.green : Color.orange)
                }
                Button {
                    model.reloadFromICloud()
                } label: {
                    Label("Sync now", systemImage: "arrow.triangle.2.circlepath.icloud")
                }
                Button {
                    model.restoreDefaults()
                } label: {
                    Label("Restore Leafs + Packers", systemImage: "arrow.uturn.backward")
                }
            } header: {
                Text("Sync")
            } footer: {
                Text("Favourites are stored in iCloud key-value storage, so Apple TV, iPhone and iPad stay in step on the same Apple ID. Scores from the public NHL and ESPN feeds; lines from Daily Faceoff.")
            }
        }
        .navigationTitle("Teams")
        #if os(iOS)
        .searchable(text: $search, prompt: "Search teams")
        .toolbar { EditButton() }
        #endif
        .confirmationDialog(
            editing.flatMap { model.catalog.team(for: $0.teamID)?.displayName } ?? "Team",
            isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } }),
            titleVisibility: .visible,
            presenting: editing
        ) { favourite in
            Button("Move up") { model.moveFavourite(favourite, by: -1) }
                .disabled(model.settings.favourites.first == favourite)
            Button("Move down") { model.moveFavourite(favourite, by: 1) }
                .disabled(model.settings.favourites.last == favourite)
            Button("Remove", role: .destructive) { model.removeFavourite(favourite) }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func favouriteRow(_ favourite: FavouriteTeam) -> some View {
        let team = model.catalog.team(for: favourite.teamID)
        let label = HStack(spacing: 14) {
            TeamLogo(url: team?.logoURL, abbreviation: favourite.code, size: Theme.isTV ? 64 : 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(team?.displayName ?? favourite.id).font(.body.weight(.semibold))
                Text([favourite.league.displayName, team?.division].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        #if os(tvOS)
        Button { editing = favourite } label: { label }
        #else
        label
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Remove") { model.removeFavourite(favourite) }
        #endif
    }

    private func addRow(_ team: TeamSummary) -> some View {
        Button {
            withAnimation { model.addFavourite(team) }
        } label: {
            HStack(spacing: 14) {
                TeamLogo(team: team, size: Theme.isTV ? 56 : 30)
                Text(team.displayName)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(team.accentColor)
                    .imageScale(.large)
            }
        }
        .accessibilityLabel("Add \(team.displayName)")
    }

    // MARK: Data

    private struct DivisionGroup {
        var name: String
        var teams: [TeamSummary]
    }

    private var divisions: [DivisionGroup] {
        let query = search.trimmingCharacters(in: .whitespaces)
        let candidates = model.catalog.teams(in: league).filter { team in
            !model.isFavourite(team)
                && (query.isEmpty || team.displayName.localizedCaseInsensitiveContains(query) || team.abbreviation.localizedCaseInsensitiveContains(query))
        }
        return Dictionary(grouping: candidates) { $0.division ?? "Other" }
            .map { DivisionGroup(name: $0.key, teams: $0.value) }
            .sorted { $0.name < $1.name }
    }
}
