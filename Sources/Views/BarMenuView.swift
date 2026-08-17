import SwiftUI

struct BarMenuView: View {
    @EnvironmentObject var barViewModel: BarViewModel
    @State private var showCart = false
    @State private var selectedItem: BarItem?
    @State private var itemQuantity = 1
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    categoryPicker
                    
                    ForEach(barViewModel.filteredMenu) { item in
                        MenuItemRow(item: item)
                            .onTapGesture {
                                selectedItem = item
                                itemQuantity = 1
                            }
                    }
                }
                .padding(.horizontal)
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Fight Night Bar")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCart = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cart.fill")
                            if barViewModel.cartTotal > 0 {
                                Text(String(format: "$%.0f", barViewModel.cartTotal))
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Theme.primaryColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCart) {
                BarCartView()
            }
            .sheet(item: $selectedItem) { item in
                ItemDetailSheet(item: item, quantity: $itemQuantity)
            }
        }
    }
    
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([BarItem.BarCategory.beer, .cocktails, .softDrinks, .snacks, .premium], id: \.self) { category in
                    Button {
                        withAnimation {
                            barViewModel.selectedCategory = category
                        }
                    } label: {
                        Text(category.rawValue)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(barViewModel.selectedCategory == category ? Theme.primaryColor : Theme.cardBackground)
                            .foregroundColor(barViewModel.selectedCategory == category ? .white : Theme.secondaryColor)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    struct MenuItemRow: View {
        @EnvironmentObject var barVM: BarViewModel
        let item: BarItem
        
        var body: some View {
            HStack(spacing: 12) {
                Text(item.emoji)
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text(String(format: "$%.0f", item.price))
                        .font(.headline)
                        .foregroundColor(Theme.primaryColor)
                    
                    Button {
                        barVM.addToOrder(item)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.primaryColor)
                    }
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
    }
    
    struct ItemDetailSheet: View {
        @EnvironmentObject var barVM: BarViewModel
        let item: BarItem
        @Binding var quantity: Int
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            VStack(spacing: 16) {
                Text(item.emoji)
                    .font(.system(size: 64))
                
                Text(item.name)
                    .font(.title2.bold())
                
                Text(item.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(String(format: "$%.0f", item.price))
                    .font(.title.bold())
                    .foregroundColor(Theme.primaryColor)
                
                HStack(spacing: 20) {
                    Button {
                        if quantity > 1 { quantity -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(Theme.secondaryColor)
                    }
                    
                    Text("\(quantity)")
                        .font(.title2.bold())
                        .frame(minWidth: 40)
                    
                    Button {
                        quantity += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(Theme.primaryColor)
                    }
                }
                
                Button {
                    for _ in 0..<quantity {
                        barVM.addToOrder(item)
                    }
                    dismiss()
                } label: {
                    Text("Add \(quantity > 1 ? "\(quantity) items" : "to Order")")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primaryColor)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
    
    struct BarCartView: View {
        @EnvironmentObject var barVM: BarViewModel
        @Environment(\.dismiss) var dismiss
        @State private var showOrderConfirmation = false
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 12) {
                        if barVM.orderItems.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "cart")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("Your order is empty")
                                    .font(.headline)
                                Text("Browse the menu and add items to your cart")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 80)
                        } else {
                            ForEach(barVM.orderItems) { orderItem in
                                CartRow(orderItem: orderItem)
                            }
                            
                            // Delivery details
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Delivery Details")
                                    .font(.headline)
                                
                                HStack {
                                    Text("Deliver to Sector")
                                    Spacer()
                                    TextField("Sector", text: $barVM.deliverySector)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Instructions")
                                        .font(.subheadline)
                                    TextField("e.g. Section B, row 5", text: $barVM.deliveryNotes)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(12)
                            
                            // Totals
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Subtotal")
                                    Spacer()
                                    Text(String(format: "$%.0f", barVM.cartTotal))
                                }
                                HStack {
                                    Text("Delivery")
                                    Spacer()
                                    Text("Free")
                                        .foregroundColor(.green)
                                }
                                Divider()
                                HStack {
                                    Text("Total")
                                        .font(.headline)
                                    Spacer()
                                    Text(String(format: "$%.0f", barVM.cartTotal))
                                        .font(.headline)
                                        .foregroundColor(Theme.primaryColor)
                                }
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(12)
                            
                            Button {
                                barVM.placeOrder()
                                showOrderConfirmation = true
                            } label: {
                                Text("Place Order")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.primaryColor)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Your Order")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
                .alert("Order Placed!", isPresented: $showOrderConfirmation) {
                    Button("OK") {
                        dismiss()
                    }
                } message: {
                    Text("Your drinks will be delivered to your seat shortly.")
                }
            }
        }
    }
    
    struct CartRow: View {
        @EnvironmentObject var barVM: BarViewModel
        let orderItem: BarOrderItem
        
        var body: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text(orderItem.item.name)
                        .font(.headline)
                    Text("\(orderItem.quantity) × $\(String(format: "%.0f", orderItem.item.price))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    barVM.removeFromOrder(orderItem.item)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(Theme.primaryColor)
                }
                Text("$\(String(format: "%.0f", Double(orderItem.quantity) * orderItem.item.price))")
                    .font(.headline)
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
        }
    }
}
