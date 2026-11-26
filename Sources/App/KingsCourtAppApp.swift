import SwiftUI

@main
struct KingsCourtAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-screenshot-mode") {
                ScreenshotRootView()
            } else {
                NyxCoveView {
                    ContentView()
                }
            }
        }
    }
}

private struct ScreenshotRootView: View {
    private var screen: String {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot-screen"),
              arguments.indices.contains(index + 1) else { return "home" }
        return arguments[index + 1]
    }

    var body: some View {
        NavigationStack {
            switch screen {
            case "matches": FixturesScreen()
            case "teams": TeamsScreen()
            case "explore": ExploreScreen()
            case "standings": StandingsScreen()
            case "bracket": BracketScreen()
            case "venues": VenuesScreen()
            case "stories": NewsScreen()
            default: HomeScreen()
            }
        }
        .tint(Color(hex: "C8FF2E"))
        .preferredColorScheme(.dark)
    }
}
