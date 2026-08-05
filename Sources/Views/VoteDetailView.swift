import SwiftUI

struct VoteDetailView: View {
    let match: Match
    let selectedFighter: Fighter
    @ObservedObject var votingViewModel: VotingViewModel
    @Environment(\.dismiss) var dismiss
    @State private var predictionMethod: Vote.PredictionMethod = .decision
    @State private var predictedRound = 2
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text(selectedFighter.name)
                    .font(.title2.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            
            Text("Make Your Prediction")
                .font(.headline)
            
            Picker("Method", selection: $predictionMethod) {
                Text("Decision").tag(Vote.PredictionMethod.decision)
                Text("Knockout").tag(Vote.PredictionMethod.knockout)
                Text("Stoppage").tag(Vote.PredictionMethod.submission)
            }
            .pickerStyle(.segmented)
            
            if predictionMethod != .decision {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Predicted Round")
                        .font(.headline)
                    
                    HStack {
                        ForEach(1...match.roundsPlanned, id: \.self) { round in
                            RoundButton(round: round, isSelected: predictedRound == round) {
                                predictedRound = round
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Decision Prediction")
                        .font(.headline)
                    Text("Fight goes the distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button {
                votingViewModel.vote(
                    match: match,
                    for: selectedFighter,
                    predictedRound: predictionMethod != .decision ? predictedRound : nil
                )
                dismiss()
            } label: {
                Text("Submit Prediction")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.primaryColor)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    struct RoundButton: View {
        let round: Int
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text("R\(round)")
                    .font(.subheadline.bold())
                    .frame(width: 48, height: 40)
                    .background(isSelected ? Theme.primaryColor : Theme.cardBackground)
                    .foregroundColor(isSelected ? .white : Theme.secondaryColor)
                    .cornerRadius(8)
            }
        }
    }
}
