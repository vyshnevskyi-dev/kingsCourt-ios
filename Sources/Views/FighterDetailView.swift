import SwiftUI

struct FighterDetailView: View {
    let fighter: Fighter
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.secondaryColor.opacity(0.1))
                                .frame(width: 120, height: 120)
                            Text(fighter.photoEmoji)
                                .font(.system(size: 60))
                        }
                        
                        Text(fighter.name)
                            .font(.title.bold())
                        
                        Text("\"\(fighter.nickname)\"")
                            .font(.headline)
                            .foregroundColor(Theme.primaryColor)
                        
                        Text(fighter.style)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Fight Record")
                            .font(.headline)
                        
                        HStack {
                            statBlock(title: "Wins", value: "\(fighter.wins)", color: .green)
                            Spacer()
                            statBlock(title: "Losses", value: "\(fighter.losses)", color: .red)
                            Spacer()
                            statBlock(title: "Draws", value: "\(fighter.draws)", color: .gray)
                        }
                        
                        Divider()
                        
                        HStack {
                            Label("Rating", systemImage: "chart.bar.fill")
                            Spacer()
                            Text(String(format: "%.1f", fighter.rating))
                                .font(.headline)
                                .foregroundColor(Theme.primaryColor)
                        }
                        
                        HStack {
                            Label("Win", systemImage: "percent")
                            Spacer()
                            Text(String(format: "%.1f%%", fighter.winPercentage))
                                .font(.headline)
                        }
                        
                        HStack {
                            Label("Age", systemImage: "birthday.cake")
                            Spacer()
                            Text("\(fighter.age)")
                        }
                        
                        HStack {
                            Label("Height", systemImage: "ruler")
                            Spacer()
                            Text(fighter.height)
                        }
                        
                        HStack {
                            Label("Reach", systemImage: "hand.raised")
                            Spacer()
                            Text(fighter.reach)
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
                    
                    // Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gym & Style")
                            .font(.headline)
                        
                        HStack {
                            Label(fighter.gym, systemImage: "building.2.fill")
                            Spacer()
                        }
                        
                        HStack {
                            Label(fighter.country, systemImage: "globe")
                            Spacer()
                        }
                        
                        HStack {
                            Label(fighter.style, systemImage: "figure.boxing")
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Fighter Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func statBlock(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
