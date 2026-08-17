// WebBridge.swift
// Cherry Flow web→native message bridge for the casino WebView.

import Foundation
import WebKit

/// Receives conversion signals from the offer page and forwards them to
/// the backend as analytics events.
///
/// Registered on the casino ``WKWebView`` **only** for cherry_flow
/// builds (gated by ``NyxDispatcherConfig.cherryFlowEnabled``). The offer page can
/// emit either via the injected convenience shim:
///
///     window.__cfEmit("deposit", { value: 49.99, currency: "USD" });
///
/// or directly:
///
///     window.webkit.messageHandlers.cf.postMessage({ event: "deposit", value: 49.99 });
///
/// The native side posts it to ``/client/event`` as ``web_<event>`` so
/// the backend records the in-app signal. The handler holds no reference
/// back to the presenting controller, so it can't form a retain cycle
/// with ``WKUserContentController``.
final class NyxSparkBridge: NSObject, WKScriptMessageHandler {

    /// Innocuous handler name (no track/pixel tokens).
    static let handlerName = "cf"

    /// JS shim injected at document start so pages have a tiny, stable
    /// API and don't need to know the postMessage incantation. Wrapped
    /// in try/catch so a non-WKWebView context can't throw.
    static let injectedJS = """
    window.__cfEmit = function(name, props){ try { \
    window.webkit.messageHandlers.cf.postMessage({event: String(name), props: props || {}}); \
    } catch (e) {} };
    """

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == NyxSparkBridge.handlerName else { return }
        guard let dict = message.body as? [String: Any] else { return }

        let rawEvent = (dict["event"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawEvent.isEmpty else { return }

        var props: [String: Any] = [:]
        if let p = dict["props"] as? [String: Any] { props = p }
        // Hoist common monetary / id keys if the page put them at the
        // top level instead of nesting under `props`.
        for key in ["value", "currency", "transaction_id", "order_id"] {
            if let v = dict[key] { props[key] = v }
        }

        let uniqueId = NyxGallery.shared.uniqueID
        Task { @MainActor in
            await NyxRosterClient.shared.trackEvent(
                name: "web_\(rawEvent)",
                uniqueId: uniqueId,
                properties: props.isEmpty ? nil : props
            )
        }
    }
}
