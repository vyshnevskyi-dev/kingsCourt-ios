import SwiftUI

@main
struct KingsCourtAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            NyxCoveView {
                ContentView()
            }
        }
    }
}
