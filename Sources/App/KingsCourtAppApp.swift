import SwiftUI

@main
struct KingsCourtAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var tournamentViewModel = TournamentViewModel()
    @StateObject private var ticketViewModel = TicketViewModel()
    @StateObject private var votingViewModel = VotingViewModel()
    @StateObject private var barViewModel = BarViewModel()
    @StateObject private var merchViewModel = MerchViewModel()
    
    var body: some Scene {
        WindowGroup {
            NyxCoveView {
            ContentView()
                .environmentObject(tournamentViewModel)
                .environmentObject(ticketViewModel)
                .environmentObject(votingViewModel)
                .environmentObject(barViewModel)
                .environmentObject(merchViewModel)
                .tint(Theme.primaryColor)
                // App is designed dark-only (Theme.backgroundColor/cardBackground
                // are hardcoded dark hex, not adaptive). Without this, system
                // chrome (List/Form grouped backgrounds, nav bars, alerts,
                // status bar) still follows the DEVICE's light/dark setting and
                // shows light chrome around our dark content on a light-mode
                // device.
                .preferredColorScheme(.dark)
            }

        }
    }
}
