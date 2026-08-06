import Foundation

struct BarItem: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let description: String
    let price: Double
    let category: BarCategory
    let emoji: String
    
    enum BarCategory: String, Hashable, Codable {
        case beer = "Beer"
        case cocktails = "Cocktails"
        case softDrinks = "Soft Drinks"
        case snacks = "Snacks"
        case premium = "Premium"
    }
    
    static let sampleItems: [BarItem] = [
        BarItem(id: UUID(), name: "Kingdom Lager", description: "Crisp artisan lager brewed locally", price: 8.0, category: .beer, emoji: "mug.fill"),
        BarItem(id: UUID(), name: "Warrior IPA", description: "Bold hoppy IPA, 6.8% ABV", price: 9.5, category: .beer, emoji: "mug.fill"),
        BarItem(id: UUID(), name: "Champion's Margarita", description: "Premium tequila with fresh lime", price: 14.0, category: .cocktails, emoji: "wineglass.fill"),
        BarItem(id: UUID(), name: "Iron Punch", description: "Vodka punch with mixed berries", price: 12.0, category: .cocktails, emoji: "wineglass.fill"),
        BarItem(id: UUID(), name: "Corner Water", description: "Still mineral water 500ml", price: 3.5, category: .softDrinks, emoji: "star.fill"),
        BarItem(id: UUID(), name: "Victory Cola", description: "Classic cola with ice", price: 4.0, category: .softDrinks, emoji: "cup.and.saucer.fill"),
        BarItem(id: UUID(), name: "Fight Night Wings", description: "Spicy chicken wings with dip", price: 10.0, category: .snacks, emoji: "star.fill"),
        BarItem(id: UUID(), name: "Champion's Board", description: "Assorted meats and cheeses", price: 22.0, category: .snacks, emoji: "fork.knife"),
        BarItem(id: UUID(), name: "Grand Reserve Whiskey", description: "18-year aged single malt", price: 28.0, category: .premium, emoji: "wineglass.fill")
    ]
}
