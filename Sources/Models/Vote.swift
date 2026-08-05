import Foundation

struct Vote: Identifiable, Hashable, Codable {
    let id: UUID
    let matchId: UUID
    let fighterId: UUID
    let predictedRound: Int?
    let predictedMethod: PredictionMethod
    
    enum PredictionMethod: String, Hashable, Codable {
        case decision = "Decision"
        case knockout = "Knockout"
        case submission = "Technical Stoppage"
    }
}
