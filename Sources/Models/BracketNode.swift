import Foundation

struct BracketNode: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let fighters: [Fighter]
    let match: Match?
    let isFanSelected: Bool
    let votingPercentage: Double
}
