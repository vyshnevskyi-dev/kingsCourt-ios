// NyxKernel.swift
// Routes a tapped push notification to the right surface
// (native screen / in-app webview / external Safari).
//
// Host apps wire this into their AppDelegate:
//
//   func userNotificationCenter(_ center: UNUserNotificationCenter,
//                               didReceive response: UNNotificationResponse,
//                               withCompletionHandler completionHandler: @escaping () -> Void) {
//       NyxKernel.handle(userInfo: response.notification.request.content.userInfo)
//       completionHandler()
//   }
//
// Payload shape sent from the server dispatcher (matches the
// campaign row in push_campaigns):
//
//   {
//     "aps": { "alert": {...}, "sound": "default", "badge": 1 },
//     "click_action": "native" | "in_app_webview" | "external",
//     "click_url": "https://…",             // in_app_webview + external
//     "deeplink_path": "/offers/abc123"      // native
//   }
//
// Policy decisions baked in:
//   * Unknown / missing click_action → native, no deeplink. We
//     never ask the web or System Safari to resolve an unknown
//     action — worst case the app just opens to its main screen.
//   * ``in_app_webview`` uses SFSafariViewController so tracking
//     cookies and user session stay on the partner's domain
//     without App Store review dragging us through a "custom
//     web view" flag. This is the same path NyxBeaconSheet
//     uses for CTA landing pages.
//   * ``external`` hands the URL to ``UIApplication.open`` which
//     triggers the system smart-banner → App Store install flow
//     for itms-apps:// / https:// links to another app.

import Foundation
import SafariServices
import UIKit

@MainActor
public enum NyxKernel {

    /// Action key the server dispatcher writes into the APNs payload.
    public enum NyxCedar: String {
        /// Open the host app's root scene. Optional ``deeplink_path``
        /// is forwarded via ``NotificationCenter`` under
        /// ``pushDeeplink`` so host apps that do their own deep-link
        /// routing can react.
        case native
        /// Open ``click_url`` inside an ``SFSafariViewController``.
        case inAppWebView = "in_app_webview"
        /// Open ``click_url`` in the system browser. Used for store
        /// links / partner-app install prompts.
        case external
    }

    /// Posted when a tapped push requests a native deep link. The
    /// notification ``object`` is the ``deeplink_path`` string (may
    /// be empty). Host apps observe this in the scene that owns
    /// deep-link routing.
    public static let pushDeeplinkNotification = Notification.Name("NyxFlow.pushDeeplink")

    /// Entry point — call from the AppDelegate's push-tap callback.
    public static func handle(userInfo: [AnyHashable: Any]) {
        let actionRaw = (userInfo["click_action"] as? String) ?? "native"
        let action = NyxCedar(rawValue: actionRaw) ?? .native
        let rawURL = (userInfo["click_url"] as? String) ?? ""
        let deeplink = (userInfo["deeplink_path"] as? String) ?? ""

        NyxMint.log("Push tap: action=\(action.rawValue) url=\(rawURL) deeplink=\(deeplink)")

        Task { @MainActor in
            await NyxDispatcherRouter.shared.trackEvent(.pushTapped, properties: [
                "action": action.rawValue,
                "url": rawURL,
                "deeplink": deeplink,
            ])
        }

        switch action {
        case .native:
            handleNative(deeplinkPath: deeplink)
        case .inAppWebView:
            handleInAppWebView(rawURL: rawURL)
        case .external:
            handleExternal(rawURL: rawURL)
        }
    }

    // MARK: - Branches

    private static func handleNative(deeplinkPath: String) {
        NotificationCenter.default.post(
            name: pushDeeplinkNotification,
            object: deeplinkPath
        )
    }

    private static func handleInAppWebView(rawURL: String) {
        guard let url = validatedHTTPURL(rawURL) else {
            NyxMint.log("Push: in_app_webview skipped — invalid url \(rawURL)")
            return
        }
        guard let topVC = topViewController() else {
            NyxMint.log("Push: no top view controller for SFSafari present")
            return
        }
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.modalPresentationStyle = .pageSheet
        topVC.present(safari, animated: true)
    }

    private static func handleExternal(rawURL: String) {
        guard let url = URL(string: rawURL), let scheme = url.scheme?.lowercased() else {
            NyxMint.log("Push: external skipped — unparseable url \(rawURL)")
            return
        }
        // Allow http(s) for App Store landing pages + itms-apps for
        // direct product-page jumps. Anything else (custom schemes
        // from third parties, file://) is dropped — the dispatcher
        // should never be serving those, and we don't want a typo
        // in admin to trigger an unexpected in-app handler.
        let allowed = ["http", "https", "itms-apps", "itms-appss"]
        guard allowed.contains(scheme) else {
            NyxMint.log("Push: external skipped — scheme \(scheme) not allowed")
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: - Helpers

    private static func validatedHTTPURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}
