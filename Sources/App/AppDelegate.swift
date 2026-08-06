import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set push delegate for deep link handling
        UNUserNotificationCenter.current().delegate = self

        // Request push token early so it's available before init request
        application.registerForRemoteNotifications()

        Task { @MainActor in
            let settings = NyxDispatcherSettings.create()
                .serverURL("https://wildcherry.cloud")
                .hasATT(false)
                .build()
            await NyxDispatcherRouter.shared.start(settings: settings)
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = NyxDispatcherRouter.tokenString(from: deviceToken)
        NyxMint.log("APNs token received: \(token.prefix(20))...")
        NyxDispatcherRouter.shared.updatePushToken(token)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NyxMint.error("APNs registration failed", error)
    }

    // MARK: - Push Notification Deep Link

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        NyxMint.log("Push tapped: \(userInfo)")

        if let urlString = userInfo["url"] as? String,
           let url = URL(string: urlString) {
            NyxMint.log("Opening push deep link: \(urlString)")
            UIApplication.shared.open(url)
        }
        completionHandler()
    }

    // Show push banner even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
