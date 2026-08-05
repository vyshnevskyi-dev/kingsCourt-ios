import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tournamentViewModel: TournamentViewModel
    @State private var selectedTab: Tab = .bracket
    
    enum Tab: String, Hashable {
        case bracket = "Bracket"
        case fighters = "Fighters"
        case schedule = "Schedule"
        case ticket = "Ticket"
        case bar = "Bar"
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BracketView()
                .tabItem {
                    Label("Bracket", systemImage: "square.grid.3x3.fill")
                }
                .tag(Tab.bracket)
            
            FightersView()
                .tabItem {
                    Label("Fighters", systemImage: "figure.boxing")
                }
                .tag(Tab.fighters)
            
            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(Tab.schedule)
            
            TicketView()
                .tabItem {
                    Label("Ticket", systemImage: "qrcode")
                }
                .tag(Tab.ticket)
            
            BarMenuView()
                .tabItem {
                    Label("Bar", systemImage: "wineglass")
                }
                .tag(Tab.bar)
        }
    }
}
