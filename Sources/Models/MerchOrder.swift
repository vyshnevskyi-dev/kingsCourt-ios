import Foundation

struct MerchOrder: Identifiable, Hashable, Codable {
    let id: UUID
    let item: MerchItem
    let size: String
    let quantity: Int
    let orderTime: Date
    let totalAmount: Double
    var status: OrderStatus
    
    enum OrderStatus: String, Hashable, Codable {
        case confirmed = "Confirmed"
        case readyForPickup = "Ready for Pickup"
        case completed = "Completed"
    }
}
