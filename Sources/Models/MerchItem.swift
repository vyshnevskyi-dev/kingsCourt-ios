import Foundation

struct MerchItem: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let description: String
    let price: Double
    let category: MerchCategory
    let emoji: String
    let sizesAvailable: [String]
    
    enum MerchCategory: String, Hashable, Codable {
        case apparel = "Apparel"
        case accessories = "Accessories"
        case collectibles = "Collectibles"
    }
    
    static let sampleItems: [MerchItem] = [
        MerchItem(id: UUID(), name: "Championship Tee", description: "Official Kings Court t-shirt with event dates", price: 35.0, category: .apparel, emoji: "tshirt.fill", sizesAvailable: ["S", "M", "L", "XL"]),
        MerchItem(id: UUID(), name: "Tournament Hoodie", description: "Premium heavyweight hoodie, black with red logo", price: 75.0, category: .apparel, emoji: "tshirt.fill", sizesAvailable: ["M", "L", "XL"]),
        MerchItem(id: UUID(), name: "Fight Night Cap", description: "Structured cap with Kings Court embroidery", price: 28.0, category: .accessories, emoji: "tshirt.fill", sizesAvailable: ["One Size"]),
        MerchItem(id: UUID(), name: "Champion Belt Replica", description: "Miniature championship belt with plaque", price: 45.0, category: .collectibles, emoji: "trophy.fill", sizesAvailable: ["One Size"]),
        MerchItem(id: UUID(), name: "Commemorative Poster", description: "Limited edition event poster, signed edition available", price: 25.0, category: .collectibles, emoji: "star.fill", sizesAvailable: ["One Size"]),
        MerchItem(id: UUID(), name: "Vodka Shot Glass Set", description: "Set of 4 event-branded shot glasses", price: 20.0, category: .accessories, emoji: "wineglass.fill", sizesAvailable: ["One Size"])
    ]
}
