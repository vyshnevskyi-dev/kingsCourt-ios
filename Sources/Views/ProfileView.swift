import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var ticketViewModel: TicketViewModel
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // User card
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.secondaryColor.opacity(0.1))
                                .frame(width: 100, height: 100)
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Theme.secondaryColor)
                        }
                        
                        Text(ticketViewModel.currentTicket.holderName)
                            .font(.title2.bold())
                        
                        Text(ticketViewModel.identifyVIP() ? "VIP Member" : "Standard Attendee")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(ticketViewModel.identifyVIP() ? Color.yellow.opacity(0.2) : Theme.primaryColor.opacity(0.1))
                            .foregroundColor(ticketViewModel.identifyVIP() ? .yellow : Theme.primaryColor)
                            .cornerRadius(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Theme.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // Stats
                    HStack(spacing: 12) {
                        StatCard(icon: "ticket.fill", title: "Ticket", value: "#1847", color: Theme.primaryColor)
                        StatCard(icon: "crown.fill", title: "VIP Status", value: "Active", color: .yellow)
                        StatCard(icon: "star.fill", title: "Predictions", value: "3", color: .purple)
                    }
                    
                    // Menu
                    VStack(spacing: 0) {
                        ProfileMenuItem(icon: "qrcode.viewfinder", title: "My Ticket") {
                            // Navigate
                        }
                        Divider()
                        ProfileMenuItem(icon: "bag.fill", title: "My Merch") {
                            // Navigate
                        }
                        Divider()
                        ProfileMenuItem(icon: "wineglass.fill", title: "My Orders") {
                            // Navigate
                        }
                        Divider()
                        ProfileMenuItem(icon: "gearshape.fill", title: "Settings") {
                            showSettings = true
                        }
                    }
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Profile")
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
    
    struct StatCard: View {
        let icon: String
        let title: String
        let value: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
        }
    }
    
    struct ProfileMenuItem: View {
        let icon: String
        let title: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundColor(Theme.primaryColor)
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
