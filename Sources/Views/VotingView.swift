import SwiftUI

struct VotingView: View {
    @EnvironmentObject var tournamentViewModel: TournamentViewModel
    @EnvironmentObject var votingViewModel: VotingViewModel
    @State private var selectedMatch: Match?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Audience Predictions Dashboard")
                        .font(Theme.headlineFont)
                        .padding(.horizontal)
                    
                    if let live = tournamentViewModel.liveMatches.first {
                        LiveVotingCard(match: live)
                    }
                    
                    ForEach(tournamentViewModel.upcomingMatches) { match in
                        VotingCard(match: match)
                            .onTapGesture {
                                selectedMatch = match
                            }
                    }
                }
                .padding()
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Predictions")
            .sheet(item: $selectedMatch) { match in
                MatchPredictionDetailView(match: match)
            }
        }
    }
    
    struct LiveVotingCard: View {
        @EnvironmentObject var votingVM: VotingViewModel
        let match: Match
        
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(.headline)
                        .foregroundColor(Theme.primaryColor)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(match.fighter1.name)
                        .font(.headline)
                    Text(match.fighter2.name)
                        .font(.headline)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.primaryColor.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    struct VotingCard: View {
        @EnvironmentObject var votingVM: VotingViewModel
        let match: Match
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(match.round)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.primaryColor.opacity(0.1))
                        .foregroundColor(Theme.primaryColor)
                        .cornerRadius(6)
                    Spacer()
                    Text(match.scheduledTime.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    VotingFighterRow(fighter: match.fighter1, percentage: votingVM.votingPercentages(for: match)[match.fighter1.id] ?? 50)
                    Text("VS")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    VotingFighterRow(fighter: match.fighter2, percentage: votingVM.votingPercentages(for: match)[match.fighter2.id] ?? 50)
                }
                
                if votingVM.hasVoted(for: match.id) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("You've predicted this fight")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    HStack {
                        Text("Tap to make your prediction")
                            .font(.caption)
                            .foregroundColor(Theme.primaryColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        
        struct VotingFighterRow: View {
            let fighter: Fighter
            let percentage: Double
            
            var body: some View {
                VStack(spacing: 4) {
                    Text(fighter.photoEmoji)
                        .font(.system(size: 28))
                    Text(fighter.name)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Text("\(Int(percentage))%")
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.primaryColor)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
