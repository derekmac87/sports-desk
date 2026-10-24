import SportsDeskCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            SwiftUI.Section("Favourite teams") {
                if model.settings.favourites.isEmpty {
                    Text("No favourites yet. Add the Leafs, Packers, or any NHL/NFL team below.")
                }
                ForEach(model.settings.favourites) { favourite in
                    if let team = model.catalog.team(for: favourite.teamID) {
                        HStack {
                            RemoteImage(url: team.logoURL, size: 36)
                            VStack(alignment: .leading) {
                                Text(team.displayName)
                                Text(team.league.displayName).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove") {
                                model.removeFavourite(favourite)
                            }
                        }
                    } else {
                        Text(favourite.id)
                    }
                }
                #if os(iOS)
                .onDelete { index in
                    index.map { model.settings.favourites[$0] }.forEach(model.removeFavourite)
                }
                .onMove(perform: model.moveFavourite)
                #endif
            }

            SwiftUI.Section("Add NHL team") {
                ForEach(available(.nhl)) { team in
                    Button {
                        model.addFavourite(team)
                    } label: {
                        teamRow(team)
                    }
                }
            }

            SwiftUI.Section("Add NFL team") {
                ForEach(available(.nfl)) { team in
                    Button {
                        model.addFavourite(team)
                    } label: {
                        teamRow(team)
                    }
                }
            }

            SwiftUI.Section("Sync") {
                Text("Favourites are stored in iCloud Key-Value storage so Apple TV, iPhone, and iPad stay in lockstep when you use the same Apple ID.")
                Button("Reload from iCloud") {
                    model.settings = model.settingsStore.load()
                    Task { await model.refresh() }
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            #if os(iOS)
            EditButton()
            #endif
        }
        .onDisappear {
            Task { await model.refresh() }
        }
    }

    private func available(_ league: League) -> [TeamSummary] {
        let selected = Set(model.settings.favourites.map(\.id))
        return model.catalog.teams(in: league).filter { !selected.contains($0.id.description) }
    }

    private func teamRow(_ team: TeamSummary) -> some View {
        HStack {
            RemoteImage(url: team.logoURL, size: 32)
            Text(team.displayName)
            Spacer()
            Image(systemName: "plus.circle")
        }
    }
}
