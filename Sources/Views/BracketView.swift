import SwiftUI

struct BracketView: View {
    @EnvironmentObject var tournamentViewModel: TournamentViewModel
    @EnvironmentObject var votingViewModel: VotingViewModel
    @State private var selectedMatch: Match?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HeaderView()
                    
                    if !tournamentViewModel.liveMatches.isEmpty {
                        LiveMatchBanner(match: tournamentViewModel.liveMatches[0])
                    }
                    
                    quarterFinalSection
                    semiFinalSection
                    finalSection
                    
                    audiencePredictionSection
                }
                .padding(.horizontal)
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Kings Court")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(item: $selectedMatch) { match in
                MatchDetailView(match: match)
            }
        }
    }
    
    private var quarterFinalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quarterfinals")
                .font(Theme.headlineFont)
                .foregroundColor(Theme.secondaryColor)
            
            ForEach(tournamentViewModel.matches.filter { $0.round == "Quarterfinal" }) { match in
                MatchRow(match: match)
                    .onTapGesture {
                        selectedMatch = match
                    }
            }
        }
    }
    
    private var semiFinalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Semifinals")
                .font(Theme.headlineFont)
                .foregroundColor(Theme.secondaryColor)
            
            ForEach(tournamentViewModel.matches.filter { $0.round == "Semifinal" }) { match in
                MatchRow(match: match)
                    .onTapGesture {
                        selectedMatch = match
                    }
            }
        }
    }
    
    private var finalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Final")
                .font(Theme.headlineFont)
                .foregroundColor(Theme.secondaryColor)
            
            ForEach(tournamentViewModel.matches.filter { $0.round == "Final" }) { match in
                MatchRow(match: match)
                    .onTapGesture {
                        selectedMatch = match
                    }
            }
        }
    }
    
    private var audiencePredictionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audience Predictions")
                .font(Theme.headlineFont)
                .foregroundColor(Theme.secondaryColor)
            
            if let nextMatch = tournamentViewModel.nextMatch() {
                PredictionCard(match: nextMatch)
            }
        }
    }
    
    private struct HeaderView: View {
        var body: some View {
            VStack(spacing: 8) {
                Text(AppConstants.tournamentName)
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.primaryColor)
                Text(AppConstants.tournamentDate)
                    .font(Theme.bodyFont)
                    .foregroundColor(.secondary)
                Text(AppConstants.venueName)
                    .font(Theme.bodyFont)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    struct LiveMatchBanner: View {
        let match: Match
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("LIVE NOW")
                        .font(.caption.bold())
                        .foregroundColor(Theme.primaryColor)
                    Spacer()
                    Text(match.ring)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(match.fighter1.name).font(.headline)
                        Text(match.fighter2.name).font(.headline)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Round \(match.roundsPlanned)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("VS")
                            .font(.title2.bold())
                            .foregroundColor(Theme.primaryColor)
                    }
                }
            }
            .padding()
            .background(Theme.primaryColor.opacity(0.1))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.primaryColor, lineWidth: 2))
        }
    }
    
    struct MatchRow: View {
        let match: Match
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(match.round)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.primaryColor)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text(match.cardType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    FighterAvatarView(fighter: match.fighter1, size: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(match.fighter1.name)
                            .font(.body)
                            .fontWeight(.medium)
                        Text("W:\(match.fighter1.wins) L:\(match.fighter1.losses) D:\(match.fighter1.draws)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("VS")
                        .font(.headline.bold())
                        .foregroundColor(Theme.primaryColor)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(match.fighter2.name)
                            .font(.body)
                            .fontWeight(.medium)
                        Text("W:\(match.fighter2.wins) L:\(match.fighter2.losses) D:\(match.fighter2.draws)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    FighterAvatarView(fighter: match.fighter2, size: 36)
                }
                
                HStack {
                    Label(match.scheduledTime.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                    Spacer()
                    Label(match.ring, systemImage: "circle.circle")
                    Spacer()
                    Text(match.status.rawValue)
                        .font(.caption.bold())
                        .foregroundColor(match.status == .completed ? .green : match.status == .inProgress ? Theme.primaryColor : .secondary)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
    }
    
    struct FighterAvatarView: View {
        let fighter: Fighter
        var size: CGFloat = 44
        
        var body: some View {
            ZStack {
                Circle()
                    .fill(Theme.secondaryColor.opacity(0.1))
                    .frame(width: size, height: size)
                Text(fighter.photoEmoji)
                    .font(.system(size: size * 0.5))
            }
        }
    }
    
    struct PredictionCard: View {
        let match: Match
        @EnvironmentObject var votingVM: VotingViewModel
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Who wins?")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    PredictionRow(
                        fighter: match.fighter1,
                        percentage: votingVM.votingPercentages(for: match)[match.fighter1.id] ?? 50,
                        isPredicted: votingVM.votes.first { $0.matchId == match.id }?.fighterId == match.fighter1.id
                    )
                    
                    Text("VS")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    PredictionRow(
                        fighter: match.fighter2,
                        percentage: votingVM.votingPercentages(for: match)[match.fighter2.id] ?? 50,
                        isPredicted: votingVM.votes.first { $0.matchId == match.id }?.fighterId == match.fighter2.id
                    )
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        
        struct PredictionRow: View {
            let fighter: Fighter
            let percentage: Double
            let isPredicted: Bool
            
            var body: some View {
                VStack(spacing: 8) {
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
                    
                    Text("\(Int(percentage))%")
                        .font(.title3.bold())
                        .foregroundColor(Theme.primaryColor)
                    
                    if isPredicted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
