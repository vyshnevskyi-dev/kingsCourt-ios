import Foundation

struct Fighter: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let nickname: String
    let photoEmoji: String
    let weightClass: String
    let wins: Int
    let losses: Int
    let draws: Int
    let rating: Double
    let age: Int
    let height: String
    let reach: String
    let gym: String
    let country: String
    let style: String
    
    var totalFights: Int { wins + losses + draws }
    var winPercentage: Double { totalFights > 0 ? Double(wins) / Double(totalFights) * 100 : 0 }
    
    static let sampleFighters: [Fighter] = [
        Fighter(id: UUID(), name: "Andrei Volkov", nickname: "The Bear", photoEmoji: "🐻", weightClass: "Heavyweight", wins: 14, losses: 2, draws: 0, rating: 94.5, age: 28, height: "6'5\"", reach: "82\"", gym: "Steel Forge MMA", country: "Russia", style: "Boxing"),
        Fighter(id: UUID(), name: "Sir Gareth Ironwood", nickname: "The Knight", photoEmoji: "🛡️", weightClass: "Heavyweight", wins: 9, losses: 1, draws: 1, rating: 91.2, age: 31, height: "6'3\"", reach: "78\"", gym: "Ironwood Academy", country: "England", style: "Armored Combat"),
        Fighter(id: UUID(), name: "Marcus Steele", nickname: "The Hammer", photoEmoji: "🔨", weightClass: "Middleweight", wins: 12, losses: 3, draws: 0, rating: 88.7, age: 26, height: "6'0\"", reach: "74\"", gym: "Iron Fist Gym", country: "USA", style: "Bare Knuckle"),
        Fighter(id: UUID(), name: "Lyudmila Petrova", nickname: "The Sniper", photoEmoji: "🎯", weightClass: "Featherweight", wins: 10, losses: 1, draws: 1, rating: 92.8, age: 24, height: "5'7\"", reach: "68\"", gym: "Red Star Combat", country: "Russia", style: "Boxing"),
        Fighter(id: UUID(), name: "Sir Alaric Voss", nickname: "The Wall", photoEmoji: "🏰", weightClass: "Light Heavyweight", wins: 7, losses: 2, draws: 2, rating: 84.3, age: 34, height: "6'2\"", reach: "76\"", gym: "Voss Keep", country: "Germany", style: "Armored Combat"),
        Fighter(id: UUID(), name: "Dmitri Kazakov", nickname: "The Storm", photoEmoji: "⚡", weightClass: "Welterweight", wins: 15, losses: 2, draws: 0, rating: 95.1, age: 29, height: "5'11\"", reach: "72\"", gym: "Siberian Wolves", country: "Russia", style: "Bare Knuckle"),
        Fighter(id: UUID(), name: "William Blackthorn", nickname: "The Reaper", photoEmoji: "💀", weightClass: "Middleweight", wins: 11, losses: 4, draws: 0, rating: 86.9, age: 33, height: "6'1\"", reach: "75\"", gym: "Blackthorn Brotherhood", country: "Scotland", style: "Armored Combat"),
        Fighter(id: UUID(), name: "Sofia Marquez", nickname: "The Viper", photoEmoji: "🐍", weightClass: "Flyweight", wins: 13, losses: 1, draws: 1, rating: 93.6, age: 27, height: "5'5\"", reach: "66\"", gym: "Cobra Strike", country: "Spain", style: "Boxing")
    ]
}
