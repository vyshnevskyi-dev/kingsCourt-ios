import Foundation
import Combine

class MerchViewModel: ObservableObject {
    @Published var merchItems: [MerchItem] = []
    @Published var cart: [MerchOrder] = []
    @Published var selectedCategory: MerchItem.MerchCategory = .apparel
    @Published var searchText = ""
    
    private let defaults = UserDefaults.standard
    
    init() {
        merchItems = MerchItem.sampleItems
        loadCart()
    }
    
    var filteredItems: [MerchItem] {
        var items = merchItems.filter { $0.category == selectedCategory }
        if !searchText.isEmpty {
            items = items.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        return items
    }
    
    var cartTotal: Double {
        cart.reduce(0) { $0 + ($1.item.price * Double($1.quantity)) }
    }
    
    func addToCart(item: MerchItem, size: String, quantity: Int) {
        let order = MerchOrder(
            id: UUID(),
            item: item,
            size: size,
            quantity: quantity,
            orderTime: Date(),
            totalAmount: item.price * Double(quantity),
            status: .confirmed
        )
        cart.append(order)
        saveCart()
    }
    
    func removeFromCart(_ order: MerchOrder) {
        cart.removeAll { $0.id == order.id }
        saveCart()
    }
    
    func totalQuantity(for item: MerchItem) -> Int {
        cart.filter { $0.item.id == item.id }.reduce(0) { $0 + $1.quantity }
    }
    
    private func saveCart() {
        if let data = try? JSONEncoder().encode(cart) {
            defaults.set(data, forKey: "merchCart")
        }
    }
    
    private func loadCart() {
        guard let data = defaults.data(forKey: "merchCart"),
              let saved = try? JSONDecoder().decode([MerchOrder].self, from: data) else { return }
        cart = saved
    }
}
