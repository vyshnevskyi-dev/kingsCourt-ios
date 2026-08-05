import SwiftUI

struct BarOrdersView: View {
    @EnvironmentObject var barViewModel: BarViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if barViewModel.orders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "takeoutbag.and.cup.and.straw")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No orders yet")
                                .font(.headline)
                            Text("Your drink orders will appear here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 80)
                    } else {
                        ForEach(barViewModel.orders) { order in
                            BarOrderCard(order: order)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.backgroundColor)
            .navigationTitle("My Orders")
        }
    }
    
    struct BarOrderCard: View {
        let order: BarOrder
        
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Order #\(String(order.orderTime.timeIntervalSince1970).suffix(4))")
                        .font(.headline)
                    Spacer()
                    Text(order.status.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(6)
                }
                
                ForEach(order.items) { item in
                    HStack {
                        Text("\(item.quantity) × \(item.item.name)")
                            .font(.body)
                        Spacer()
                        Text(String(format: "$%.0f", Double(item.quantity) * item.item.price))
                            .font(.body.bold())
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Sector: \(order.sector)")
                    Spacer()
                    Text("Total: $\(String(format: "%.0f", order.totalAmount))")
                        .font(.headline)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        
        private var statusColor: Color {
            switch order.status {
            case .preparing:
                return .orange
            case .delivering:
                return .blue
            case .delivered:
                return .green
            case .pending:
                return .gray
            }
        }
    }
}
