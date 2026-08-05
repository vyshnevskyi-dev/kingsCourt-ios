import SwiftUI

struct MerchCartView: View {
    @EnvironmentObject var merchViewModel: MerchViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if merchViewModel.cart.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "bag")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("Your bag is empty")
                                .font(.headline)
                            Text("Explore the tournament merch and add items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 80)
                    } else {
                        ForEach(merchViewModel.cart) { order in
                            MerchCartRow(order: order)
                        }
                        
                        VStack(spacing: 8) {
                            Divider()
                            HStack {
                                Text("Total")
                                    .font(.headline)
                                Spacer()
                                Text(String(format: "$%.0f", merchViewModel.cartTotal))
                                    .font(.headline)
                                    .foregroundColor(Theme.primaryColor)
                            }
                            
                            Text("Pickup at the Merch Stand (Hall B)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        
                        Button {
                            showConfirmation = true
                        } label: {
                            Text("Confirm Order")
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
            .navigationTitle("Your Bag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Order Confirmed", isPresented: $showConfirmation) {
                Button("OK") {
                    merchViewModel.cart.removeAll()
                    dismiss()
                }
            } message: {
                Text("Your order has been placed. Pick up your items at the Merch Stand.")
            }
        }
    }
    
    struct MerchCartRow: View {
        @EnvironmentObject var merchVM: MerchViewModel
        let order: MerchOrder
        
        var body: some View {
            HStack(spacing: 12) {
                Text(order.item.emoji)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.item.name)
                        .font(.headline)
                    Text("Size: \(order.size) • Qty: \(order.quantity)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%.0f", order.totalAmount))
                        .font(.headline)
                    Button {
                        merchVM.removeFromCart(order)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
        }
    }
}
