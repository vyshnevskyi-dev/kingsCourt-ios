


import Foundation
import WebKit


















final class NyxSparkBridge: NSObject, WKScriptMessageHandler {

    
    static let handlerName = "cf"

    
    
    
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
        
        
        for key in ["value", "currency", "transaction_id", "order_id"] {
            if let v = dict[key] { props[key] = v }
        }

        let uniqueId = NyxGallery.shared.uniqueID
        Task { @MainActor in
            await NyxCompassClient.shared.trackEvent(
                name: "web_\(rawEvent)",
                uniqueId: uniqueId,
                properties: props.isEmpty ? nil : props
            )
        }
    }
}
