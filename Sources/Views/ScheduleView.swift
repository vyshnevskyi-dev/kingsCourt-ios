import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var tournamentViewModel: TournamentViewModel
    @State private var selectedDay = 0
    @State private var showDetailMatch: Match?
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                countdownCard
                
                Picker("Day", selection: $selectedDay) {
                    Text("Day 1").tag(0)
                    Text("Day 2").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                List {
                    Section(header: Text("Undercard")) {
                        ForEach(tournamentViewModel.matches.filter { $0.cardType == .undercard }) { match in
                            MatchScheduleRow(match: match)
                                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                .onTapGesture {
                                    showDetailMatch = match
                                }
                        }
                    }
                    
                    Section(header: Text("Main Card")) {
                        ForEach(tournamentViewModel.matches.filter { $0.cardType == .mainCard || $0.cardType == .titleFight }) { match in
                            MatchScheduleRow(match: match)
                                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                .onTapGesture {
                                    showDetailMatch = match
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Schedule")
            .onReceive(timer) { _ in
                currentTime = Date()
            }
            .sheet(item: $showDetailMatch) { match in
                MatchDetailView(match: match)
            }
        }
    }
    
    private var countdownCard: some View {
        let nextMatch = tournamentViewModel.nextMatch()
        let interval = nextMatch?.scheduledTime.timeIntervalSince(currentTime) ?? 0
        
        return VStack(spacing: 8) {
            if interval > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next Fight")
                            .font(.caption.bold())
                            .foregroundColor(Theme.primaryColor)
                        
                        Text("\(nextMatch?.fighter1.name ?? "") vs \(nextMatch?.fighter2.name ?? "")")
                            .font(.headline)
                        
                        Text("\(nextMatch?.ring ?? "") • \(nextMatch?.cardType.rawValue ?? "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Starts in")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(tournamentViewModel.formatTimeInterval(max(0, interval)))
                            .font(.title2.monospacedDigit().bold())
                            .foregroundColor(interval < 600 ? Theme.primaryColor : Theme.secondaryColor)
                    }
                }
                .padding()
                .background(Theme.cardBackground)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            } else {
                Text("Main card starts soon!")
                    .font(.headline)
                    .padding()
            }
        }
        .padding(.horizontal)
    }
    
    struct MatchScheduleRow: View {
        let match: Match
        
        var body: some View {
            HStack(spacing: 12) {
                VStack(alignment: .center, spacing: 4) {
                    Text(match.scheduledTime, format: .dateTime.hour().minute())
                        .font(.headline)
                        .foregroundColor(Theme.primaryColor)
                    Text(match.ring)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 70)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(match.fighter1.name)
                            .font(.body)
                            .fontWeight(.medium)
                        Text("W:\(match.fighter1.wins)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(match.fighter2.name)
                            .font(.body)
                            .fontWeight(.medium)
                        Text("W:\(match.fighter2.wins)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(match.cardType.rawValue.uppercased())
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(match.cardType == .titleFight ? Theme.primaryColor : .gray)
                        .cornerRadius(4)
                    
                    Text(match.status.rawValue)
                        .font(.caption)
                        .foregroundColor(match.status == .completed ? .green : match.status == .inProgress ? Theme.primaryColor : .secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
