import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var tournamentViewModel: TournamentViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if tournamentViewModel.completedMatches.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No completed fights yet")
                                .font(.headline)
                            Text("Check back after the first match")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 80)
                    } else {
                        ForEach(tournamentViewModel.completedMatches) { match in
                            ResultCard(match: match)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Results")
        }
    }
    
    struct ResultCard: View {
        let match: Match
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(match.round)
                        .font(.caption.bold())
                        .foregroundColor(Theme.primaryColor)
                    Spacer()
                    Text(match.scheduledTime.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    FighterResultColumn(fighter: match.fighter1, isWinner: Bool.random())
                    
                    VStack {
                        Text("VS")
                            .font(.title2.bold())
                            .foregroundColor(Theme.primaryColor)
                        Text("\(match.cardType.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    FighterResultColumn(fighter: match.fighter2, isWinner: !Bool.random())
                }
                
                Divider()
                
                HStack {
                    Label("Strikes: \(Int.random(in: 50...120)) - \(Int.random(in: 30...100))", systemImage: "target")
                        .font(.caption)
                    Spacer()
                    Button {
                        // Watch replay action
                    } label: {
                        Label("Replay", systemImage: "play.circle.fill")
                            .font(.caption.bold())
                            .foregroundColor(Theme.primaryColor)
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        
        struct FighterResultColumn: View {
            let fighter: Fighter
            let isWinner: Bool
            
            var body: some View {
                VStack(spacing: 6) {
                    ZStack(alignment: .topTrailing) {
                        ZStack {
                            Circle()
                                .fill(Theme.secondaryColor.opacity(0.1))
                                .frame(width: 50, height: 50)
                            Text(fighter.photoEmoji)
                                .font(.system(size: 26))
                        }
                        
                        if isWinner {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                                .offset(x: 8, y: -4)
                        }
                    }
                    Text(fighter.name)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Text("\(fighter.wins)-\(fighter.losses)-\(fighter.draws)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
