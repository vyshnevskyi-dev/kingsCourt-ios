import Foundation
import Combine

class TournamentViewModel: ObservableObject {
    @Published var matches: [Match] = []
    @Published var selectedMatch: Match?
    @Published var searchText: String = ""
    
    init() {
        matches = Match.sampleMatches()
    }
    
    var filteredMatches: [Match] {
        guard !searchText.isEmpty else { return matches }
        return matches.filter { match in
            match.fighter1.name.lowercased().contains(searchText.lowercased()) ||
            match.fighter2.name.lowercased().contains(searchText.lowercased()) ||
            match.cardType.rawValue.lowercased().contains(searchText.lowercased())
        }
    }
    
    var upcomingMatches: [Match] {
        matches.filter { $0.status == .scheduled }
    }
    
    var liveMatches: [Match] {
        matches.filter { $0.status == .inProgress }
    }
    
    var completedMatches: [Match] {
        matches.filter { $0.status == .completed }
    }
    
    var allFighters: [Fighter] {
        Fighter.sampleFighters
    }
    
    func nextMatch() -> Match? {
        matches
            .filter { $0.status == .scheduled }
            .sorted { $0.scheduledTime < $1.scheduledTime }
            .first
    }
    
    func updateMatchStatus(_ match: Match, to status: Match.MatchStatus) {
        guard let index = matches.firstIndex(where: { $0.id == match.id }) else { return }
        matches[index].status = status
    }
    
    func timeUntilNextMatch() -> TimeInterval {
        guard let next = nextMatch() else { return 0 }
        return next.scheduledTime.timeIntervalSince(Date())
    }
    
    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
