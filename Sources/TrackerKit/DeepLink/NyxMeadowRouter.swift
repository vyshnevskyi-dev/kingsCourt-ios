// NyxMeadowRouter.swift
// Custom-scheme + universal-link dispatcher for NyxFlow apps.
//
// Host-app SceneDelegate wiring:
//
//   func scene(_ scene: UIScene, openURLContexts ctx: Set<UIOpenURLContext>) {
//       if let url = ctx.first?.url { NyxMeadowRouter.shared.handle(url: url) }
//   }
//   func scene(_ scene: UIScene, continue activity: NSUserActivity) {
//       NyxMeadowRouter.shared.handle(userActivity: activity)
//   }
//
// Behaviour:
//   - URL is accepted only if the scheme matches ``NyxDispatcherConfig.deepLinkScheme``
//     OR the host matches an entry in ``NyxDispatcherConfig.universalDomains``. Every
//     other URL is dropped so a rogue universal link can't smuggle state
//     into the router.
//   - Recognised URLs emit a ``deep_link_opened`` event with ``source``,
//     raw ``url``, optional ``landing`` override, plus every attribution
//     parameter (``af_*`` / ``utm_*`` / ``click_*``) forwarded verbatim.
//   - When a query parameter named ``open_url`` / ``landing_url`` / ``l``
//     carries an http(s) URL, the router is flipped into ``.webContent``.
//     This lets partner campaigns land users directly on the target page
//     without a second ``/init`` round trip.
//   - Host apps may intercept via ``NyxCluster``; returning
//     ``true`` from ``deepLinkRouter(shouldHandle:)`` fully short-circuits
//     the built-in pipeline (no event, no state change).

import Foundation
import UIKit

@MainActor
protocol NyxCluster: AnyObject {
    /// Return ``true`` if the host app fully handled this URL. The SDK
    /// will then skip its own dispatch (no event emit, no state change).
    func deepLinkRouter(shouldHandle url: URL) -> Bool
}

extension NyxCluster {
    func deepLinkRouter(shouldHandle url: URL) -> Bool { false }
}

@MainActor
final class NyxMeadowRouter {

    // MARK: - Singleton

    static let shared = NyxMeadowRouter()

    weak var delegate: NyxCluster?

    // MARK: - Config

    /// Query-parameter names interpreted as "open this URL in the web
    /// content view". Order matters: first match wins.
    private static let landingParamKeys: [String] = [
        "open_url", "landing_url", "l",
    ]

    /// Prefixes that identify attribution params we forward to the
    /// backend. Kept intentionally narrow — any other params stay
    /// private to the app.
    private static let attributionPrefixes: [String] = [
        "af_", "utm_", "click_",
    ]

    private init() {}

    // MARK: - Public entrypoints

    /// Handle a custom-scheme URL (e.g. ``myapp://open?…``) received
    /// via ``scene(_:openURLContexts:)``.
    func handle(url: URL) {
        guard isRecognised(url: url) else {
            NyxMint.log("DeepLink: ignoring \(url.absoluteString) — not for this app")
            return
        }
        dispatch(url: url, source: "url_scheme")
    }

    /// Handle an ``NSUserActivity`` from a universal link received via
    /// ``scene(_:continue:)``.
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

    // MARK: - Dispatch

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

    // MARK: - Recognition

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

    // MARK: - Parsing

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
