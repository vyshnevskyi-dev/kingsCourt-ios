import Foundation

struct BarOrderItem: Identifiable, Hashable, Codable {
    let id: UUID
    let item: BarItem
    var quantity: Int
    let notes: String?
}

struct BarOrder: Identifiable, Hashable, Codable {
    let id: UUID
    let items: [BarOrderItem]
    let sector: String
    let deliveryInstructions: String
    let orderTime: Date
    let totalAmount: Double
    var status: OrderStatus
    
    enum OrderStatus: String, Hashable, Codable {
        case pending = "Preparing"
        case preparing = "In Progress"
        case delivering = "On the Way"
        case delivered = "Delivered"
    }
}
