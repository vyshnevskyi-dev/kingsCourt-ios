import Foundation
import Combine

class BarViewModel: ObservableObject {
    @Published var menuItems: [BarItem] = []
    @Published var orderItems: [BarOrderItem] = []
    @Published var orders: [BarOrder] = []
    @Published var selectedCategory: BarItem.BarCategory = .beer
    @Published var deliverySector = "VIP-01"
    @Published var deliveryNotes = ""
    
    private let defaults = UserDefaults.standard
    
    init() {
        menuItems = BarItem.sampleItems
        loadCart()
        loadOrders()
    }
    
    var filteredMenu: [BarItem] {
        menuItems.filter { $0.category == selectedCategory }
    }
    
    var cartTotal: Double {
        orderItems.reduce(0) { $0 + ($1.item.price * Double($1.quantity)) }
    }
    
    func addToOrder(_ item: BarItem) {
        if let index = orderItems.firstIndex(where: { $0.item.id == item.id }) {
            orderItems[index].quantity += 1
        } else {
            orderItems.append(BarOrderItem(id: UUID(), item: item, quantity: 1, notes: nil))
        }
        saveCart()
    }
    
    func removeFromOrder(_ item: BarItem) {
        guard let index = orderItems.firstIndex(where: { $0.item.id == item.id }) else { return }
        if orderItems[index].quantity > 1 {
            orderItems[index].quantity -= 1
        } else {
            orderItems.remove(at: index)
        }
        saveCart()
    }
    
    func placeOrder() {
        guard !orderItems.isEmpty else { return }
        
        let newOrder = BarOrder(
            id: UUID(),
            items: orderItems,
            sector: deliverySector,
            deliveryInstructions: deliveryNotes,
            orderTime: Date(),
            totalAmount: cartTotal,
            status: .preparing
        )
        
        orders.append(newOrder)
        orderItems.removeAll()
        saveCart()
        saveOrders()
    }
    
    private func saveCart() {
        if let data = try? JSONEncoder().encode(orderItems) {
            defaults.set(data, forKey: "barCart")
        }
    }
    
    private func loadCart() {
        guard let data = defaults.data(forKey: "barCart"),
              let items = try? JSONDecoder().decode([BarOrderItem].self, from: data) else { return }
        orderItems = items
    }
    
    private func saveOrders() {
        if let data = try? JSONEncoder().encode(orders) {
            defaults.set(data, forKey: "barOrders")
        }
    }
    
    private func loadOrders() {
        guard let data = defaults.data(forKey: "barOrders"),
              let saved = try? JSONDecoder().decode([BarOrder].self, from: data) else { return }
        orders = saved
    }
}
