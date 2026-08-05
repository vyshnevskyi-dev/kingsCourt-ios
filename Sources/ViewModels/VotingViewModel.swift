import Foundation
import Combine

class VotingViewModel: ObservableObject {
    @Published var votes: [Vote] = []
    @Published var showVoteConfirmation = false
    @Published var predictedRound: Int = 2
    
    private let defaults = UserDefaults.standard
    
    init() {
        loadVotes()
    }
    
    func hasVoted(for matchId: UUID) -> Bool {
        votes.contains { $0.matchId == matchId }
    }
    
    func vote(match: Match, for fighter: Fighter, predictedRound: Int? = nil) {
        let method: Vote.PredictionMethod = predictedRound != nil ? .knockout : .decision
        
        let newVote = Vote(
            id: UUID(),
            matchId: match.id,
            fighterId: fighter.id,
            predictedRound: predictedRound,
            predictedMethod: method
        )
        
        votes.append(newVote)
        showVoteConfirmation = true
        saveVotes()
    }
    
    func voteCount(for matchId: UUID, fighterId: UUID) -> Int {
        // Simulated live vote counts
        let base = Int(abs(fighterId.uuidString.hashValue) % 100)
        return base + votes.filter { $0.matchId == matchId && $0.fighterId == fighterId }.count * 2
    }
    
    func votingPercentages(for match: Match) -> [UUID: Double] {
        let f1Votes = Double(voteCount(for: match.id, fighterId: match.fighter1.id))
        let f2Votes = Double(voteCount(for: match.id, fighterId: match.fighter2.id))
        let total = f1Votes + f2Votes
        
        if total == 0 { return [:] }
        return [match.fighter1.id: f1Votes / total * 100, match.fighter2.id: f2Votes / total * 100]
    }
    
    func predictedRoundDistribution(for match: Match) -> [Int: Double] {
        var distribution: [Int: Double] = [:]
        let rounds = match.roundsPlanned
        
        for round in 1...rounds {
            let base = Double(100 / rounds)
            let variance = Double(Int(match.id.uuidString.hashValue) % 20) - 10
            distribution[round] = max(5, base + variance / Double(round))
        }
        
        return distribution
    }
    
    private func saveVotes() {
        // Simple persistence of vote IDs
        if let data = try? JSONEncoder().encode(votes) {
            defaults.set(data, forKey: "userVotes")
        }
    }
    
    private func loadVotes() {
        guard let data = defaults.data(forKey: "userVotes") else { return }
        votes = (try? JSONDecoder().decode([Vote].self, from: data)) ?? []
    }
}
