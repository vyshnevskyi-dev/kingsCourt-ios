import SwiftUI

struct MatchDetailView: View {
    let match: Match
    @EnvironmentObject var votingViewModel: VotingViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showVoting = false
    @State private var selectedFighter: Fighter?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    fightHeader
                    
                    fighterComparison
                    
                    if votingViewModel.hasVoted(for: match.id) {
                        voteConfirmationView
                    } else if match.status == .scheduled {
                        voteButton
                    }
                    
                    if match.status == .completed {
                        resultView
                    }
                    
                    if match.status == .inProgress {
                        liveScoreView
                    }
                }
                .padding()
            }
            .background(Theme.backgroundColor)
            .navigationTitle("\(match.round)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedFighter) { fighter in
                VoteDetailView(match: match, selectedFighter: fighter, votingViewModel: votingViewModel)
            }
        }
    }
    
    private var fightHeader: some View {
        VStack(spacing: 8) {
            Text(match.cardType.rawValue)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.primaryColor.opacity(0.1))
                .foregroundColor(Theme.primaryColor)
                .cornerRadius(8)
            
            Text("\(match.scheduledTime.formatted(.dateTime.weekday().month().day().hour().minute()))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("\(match.ring) • \(match.roundsPlanned) rounds planned")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var fighterComparison: some View {
        HStack(spacing: 12) {
            FighterCompareCard(fighter: match.fighter1)
            
            VStack(spacing: 8) {
                Text("VS")
                    .font(.title2.bold())
                    .foregroundColor(Theme.primaryColor)
                Text("Reach: \(match.fighter1.reach) vs \(match.fighter2.reach)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            FighterCompareCard(fighter: match.fighter2)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
    
    private var voteButton: some View {
        VStack(spacing: 12) {
            Text("Your Prediction")
                .font(.headline)
            
            HStack(spacing: 10) {
                Button {
                    selectedFighter = match.fighter1
                } label: {
                    VStack(spacing: 4) {
                        Text(match.fighter1.photoEmoji)
                            .font(.system(size: 28))
                        Text("\(match.fighter1.name)")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Theme.secondaryColor.opacity(0.05))
                    .cornerRadius(10)
                }
                
                Button {
                    selectedFighter = match.fighter2
                } label: {
                    VStack(spacing: 4) {
                        Text(match.fighter2.photoEmoji)
                            .font(.system(size: 28))
                        Text("\(match.fighter2.name)")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Theme.secondaryColor.opacity(0.05))
                    .cornerRadius(10)
                }
            }
            
            Text("Choose the fighter you think wins")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
    
    private var voteConfirmationView: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.green)
            Text("You've made your prediction for this fight")
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var resultView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Result")
                .font(.headline)
            
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                Text("\(match.fighter1.name) wins by Decision")
                    .font(.body.bold())
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .cornerRadius(10)
            
            // Stats
            HStack {
                statBlock(title: "Total Strikes", value: "\(Int.random(in: 40...80)) vs \(Int.random(in: 30...70))")
                Spacer()
                statBlock(title: "Significant", value: "\(Int.random(in: 20...45)) vs \(Int.random(in: 15...40))")
            }
            
            // Watch replay button
            Button {
                // Video replay placeholder
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Watch Replay")
                }
                .font(.headline)
                .foregroundColor(Theme.primaryColor)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Theme.cardBackground)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
    
    private var liveScoreView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Scoring")
                .font(.headline)
                .foregroundColor(Theme.primaryColor)
            
            HStack {
                Text("Round 3 of \(match.roundsPlanned)")
                    .font(.subheadline)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
            }
            
            // Simulated round scores
            ForEach(1...3, id: \.self) { round in
                HStack {
                    Text("Round \(round)")
                        .font(.caption)
                    Spacer()
                    Text("\(Int.random(in: 8...10)) - \(Int.random(in: 8...10))")
                        .font(.subheadline.bold())
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(Theme.primaryColor.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.primaryColor.opacity(0.3), lineWidth: 1))
    }
    
    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
    }
    
    struct FighterCompareCard: View {
        let fighter: Fighter
        
        var body: some View {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Theme.secondaryColor.opacity(0.1))
                        .frame(width: 60, height: 60)
                    Text(fighter.photoEmoji)
                        .font(.system(size: 30))
                }
                Text(fighter.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(fighter.weightClass)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(fighter.wins)-\(fighter.losses)-\(fighter.draws)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
