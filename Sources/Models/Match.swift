import Foundation

struct Match: Identifiable, Hashable, Codable {
    let id: UUID
    let fighter1: Fighter
    let fighter2: Fighter
    let round: String
    let scheduledTime: Date
    let ring: String
    let cardType: CardType
    var status: MatchStatus
    var roundsPlanned: Int
    
    enum CardType: String, Hashable, Codable {
        case undercard = "Undercard"
        case mainCard = "Main Card"
        case titleFight = "Title Fight"
    }
    
    enum MatchStatus: String, Hashable, Codable {
        case scheduled = "Scheduled"
        case inProgress = "In Progress"
        case completed = "Completed"
    }
    
    static func sampleMatches() -> [Match] {
        let fighters = Fighter.sampleFighters
        let calendar = Calendar.current
        let day1 = calendar.date(byAdding: .day, value: 0, to: Date())!
        
        func makeDate(_ hour: Int, _ minute: Int, day: Date = day1) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? Date()
        }
        
        return [
            Match(id: UUID(), fighter1: fighters[2], fighter2: fighters[6], round: "Quarterfinal", scheduledTime: makeDate(15, 0), ring: "Ring A", cardType: .undercard, status: .completed, roundsPlanned: 3),
            Match(id: UUID(), fighter1: fighters[3], fighter2: fighters[7], round: "Quarterfinal", scheduledTime: makeDate(15, 30), ring: "Ring A", cardType: .undercard, status: .completed, roundsPlanned: 3),
            Match(id: UUID(), fighter1: fighters[4], fighter2: fighters[1], round: "Quarterfinal", scheduledTime: makeDate(16, 0), ring: "Ring B", cardType: .undercard, status: .completed, roundsPlanned: 3),
            Match(id: UUID(), fighter1: fighters[5], fighter2: fighters[0], round: "Semifinal", scheduledTime: makeDate(17, 0), ring: "Ring A", cardType: .mainCard, status: .inProgress, roundsPlanned: 5),
            Match(id: UUID(), fighter1: fighters[1], fighter2: fighters[3], round: "Semifinal", scheduledTime: makeDate(18, 0), ring: "Ring A", cardType: .mainCard, status: .scheduled, roundsPlanned: 5),
            Match(id: UUID(), fighter1: fighters[0], fighter2: fighters[3], round: "Final", scheduledTime: makeDate(20, 0), ring: "Ring A", cardType: .titleFight, status: .scheduled, roundsPlanned: 7)
        ]
    }
}
