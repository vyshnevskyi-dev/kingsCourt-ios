import SwiftUI

@main
struct KingsCourtAppApp: App {
    @StateObject private var tournamentViewModel = TournamentViewModel()
    @StateObject private var ticketViewModel = TicketViewModel()
    @StateObject private var votingViewModel = VotingViewModel()
    @StateObject private var barViewModel = BarViewModel()
    @StateObject private var merchViewModel = MerchViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tournamentViewModel)
                .environmentObject(ticketViewModel)
                .environmentObject(votingViewModel)
                .environmentObject(barViewModel)
                .environmentObject(merchViewModel)
                .tint(Theme.primaryColor)
        }
    }
}
