import SwiftUI

struct MatchPredictionDetailView: View {
    let match: Match
    @EnvironmentObject var votingViewModel: VotingViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showVotingSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(match.fighter1.name)
                        .font(.title3.bold())
                    Text("VS")
                        .font(.title.bold())
                        .foregroundColor(Theme.primaryColor)
                    Text(match.fighter2.name)
                        .font(.title3.bold())
                    
                    Divider()
                    
                    Text("Current Predictions")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        PredictionBar(
                            fighter: match.fighter1,
                            percentage: votingViewModel.votingPercentages(for: match)[match.fighter1.id] ?? 50
                        )
                        PredictionBar(
                            fighter: match.fighter2,
                            percentage: votingViewModel.votingPercentages(for: match)[match.fighter2.id] ?? 50
                        )
                    }
                    
                    if !votingViewModel.hasVoted(for: match.id) {
                        Button {
                            showVotingSheet = true
                        } label: {
                            Text("Make Your Prediction")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.primaryColor)
                                .cornerRadius(12)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Prediction submitted")
                                .font(.headline)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Predictions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showVotingSheet) {
                VoteDetailView(match: match, selectedFighter: match.fighter1, votingViewModel: votingViewModel)
            }
        }
    }
    
    struct PredictionBar: View {
        let fighter: Fighter
        let percentage: Double
        
        var body: some View {
            VStack(spacing: 8) {
                Text(fighter.photoEmoji)
                    .font(.system(size: 30))
                Text(fighter.name)
                    .font(.caption.bold())
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                        Rectangle()
                            .fill(Theme.primaryColor)
                            .frame(width: geo.size.width * percentage / 100)
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                }
                .frame(height: 8)
                Text("\(Int(percentage))%")
                    .font(.headline)
                    .foregroundColor(Theme.primaryColor)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
