



































import Foundation
import SafariServices
import UIKit

@MainActor
public enum NyxMonitor {

    
    public enum NyxCedar: String {
        
        
        
        
        case native
        
        case inAppWebView = "in_app_webview"
        
        
        case external
    }

    
    
    
    
    public static let pushDeeplinkNotification = Notification.Name("NyxFlow.pushDeeplink")

    
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
        
        
        
        
        
        let allowed = ["http", "https", "itms-apps", "itms-appss"]
        guard allowed.contains(scheme) else {
            NyxMint.log("Push: external skipped — scheme \(scheme) not allowed")
            return
        }
        UIApplication.shared.open(url)
    }

    

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
