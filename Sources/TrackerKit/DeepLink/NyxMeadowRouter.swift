



























import Foundation
import UIKit

@MainActor
protocol NyxCluster: AnyObject {
    
    
    func deepLinkRouter(shouldHandle url: URL) -> Bool
}

extension NyxCluster {
    func deepLinkRouter(shouldHandle url: URL) -> Bool { false }
}

@MainActor
final class NyxMeadowRouter {

    

    static let shared = NyxMeadowRouter()

    weak var delegate: NyxCluster?

    

    
    
    private static let landingParamKeys: [String] = [
        "open_url", "landing_url", "l",
    ]

    
    
    
    private static let attributionPrefixes: [String] = [
        "af_", "utm_", "click_",
    ]

    private init() {}

    

    
    
    func handle(url: URL) {
        guard isRecognised(url: url) else {
            NyxMint.log("DeepLink: ignoring \(url.absoluteString) — not for this app")
            return
        }
        dispatch(url: url, source: "url_scheme")
    }

    
    
    func handle(userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return
        }
        guard isRecognised(url: url) else {
            NyxMint.log("DeepLink: universal link \(url.absoluteString) rejected — domain not whitelisted")
            return
        }
        dispatch(url: url, source: "universal_link")
    }

    

    private func dispatch(url: URL, source: String) {
        if delegate?.deepLinkRouter(shouldHandle: url) == true {
            NyxMint.log("DeepLink: delegate claimed \(url.absoluteString)")
            return
        }

        let params = queryParams(from: url)
        let attribution = attributionPayload(from: params)
        let landing = landingURL(from: params)

        var props: [String: Any] = [
            "source": source,
            "url": url.absoluteString,
        ]
        if let landing = landing {
            props["landing"] = landing.absoluteString
        }
        for (key, value) in attribution {
            props[key] = value
        }

        Task { [props] in
            await NyxDispatcherRouter.shared.trackEvent(.deepLinkOpened, properties: props)
        }

        if let landing = landing {
            NyxMint.log("DeepLink: opening landing \(landing.absoluteString)")
            NyxDispatcherRouter.shared.openWebContent(url: landing)
        }
    }

    

    private func isRecognised(url: URL) -> Bool {
        if let scheme = url.scheme?.lowercased() {
            let configured = NyxDispatcherConfig.deepLinkScheme.lowercased()
            if !configured.isEmpty, scheme == configured {
                return true
            }
        }
        if let host = url.host?.lowercased(),
           NyxDispatcherConfig.universalDomains.contains(where: { $0.lowercased() == host }) {
            return true
        }
        return false
    }

    

    private func queryParams(from url: URL) -> [String: String] {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems else {
            return [:]
        }
        var result: [String: String] = [:]
        for item in items {
            if let value = item.value {
                result[item.name] = value
            }
        }
        return result
    }

    private func attributionPayload(from params: [String: String]) -> [String: String] {
        params.filter { key, _ in
            Self.attributionPrefixes.contains { prefix in key.hasPrefix(prefix) }
        }
    }

    private func landingURL(from params: [String: String]) -> URL? {
        for key in Self.landingParamKeys {
            guard let raw = params[key],
                  let url = URL(string: raw),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else { continue }
            return url
        }
        return nil
    }
}
