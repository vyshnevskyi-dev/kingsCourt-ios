import SwiftUI

struct FightersView: View {
    @EnvironmentObject var tournamentViewModel: TournamentViewModel
    @State private var searchText = ""
    @State private var selectedFighter: Fighter?
    
    private var filteredFighterGroups: [String: [Fighter]] {
        let fighters = tournamentViewModel.allFighters.filter { fighter in
            searchText.isEmpty || fighter.name.localizedCaseInsensitiveContains(searchText) || fighter.weightClass.localizedCaseInsensitiveContains(searchText)
        }
        
        return Dictionary(grouping: fighters) { $0.weightClass }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredFighterGroups.keys.sorted(), id: \.self) { weightClass in
                    Section(header: Text(weightClass)) {
                        ForEach(filteredFighterGroups[weightClass] ?? []) { fighter in
                            FighterCardView(fighter: fighter)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .onTapGesture {
                                    selectedFighter = fighter
                                }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search fighters by name or weight class")
            .navigationTitle("Fighters")
            .refreshable {
                // Simulate refresh
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            .sheet(item: $selectedFighter) { fighter in
                FighterDetailView(fighter: fighter)
            }
        }
    }
    
    struct FighterCardView: View {
        let fighter: Fighter
        
        var body: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.secondaryColor.opacity(0.1))
                        .frame(width: 60, height: 60)
                    Text(fighter.photoEmoji)
                        .font(.system(size: 30))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(fighter.name)
                            .font(.headline)
                        if fighter.rating >= 90 {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                    
                    Text("\"\(fighter.nickname)\"")
                        .font(.caption)
                        .foregroundColor(Theme.primaryColor)
                    
                    HStack(spacing: 12) {
                        Label("\(fighter.wins)-\(fighter.losses)-\(fighter.draws)", systemImage: "figure.boxing")
                        Label(String(format: "%.1f", fighter.rating), systemImage: "chart.bar.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
    }
}
